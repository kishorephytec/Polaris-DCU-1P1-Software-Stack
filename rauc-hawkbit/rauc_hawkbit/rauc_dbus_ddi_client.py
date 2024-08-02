# -*- coding: utf-8 -*-

import asyncio
from aiohttp.client_exceptions import ClientOSError, ClientResponseError
from gi.repository import GLib
from datetime import datetime, timedelta
import os
import os.path
import re
import logging

import json
import tarfile
import shutil
import time

from .dbus_client import AsyncDBUSClient
from .ddi.client import DDIClient, APIError
from .ddi.client import (
    ConfigStatusExecution, ConfigStatusResult)
from .ddi.deployment_base import (
    DeploymentStatusExecution, DeploymentStatusResult)
from .ddi.cancel_action import (
    CancelStatusExecution, CancelStatusResult)

APP_CONFIG_FILE = "./config.mk"


class RaucDBUSDDIClient(AsyncDBUSClient):
    """
    Client broker communicating with RAUC via DBUS and HawkBit DDI HTTP
    interface.
    """
    def __init__(self, session, host, ssl, tenant_id, target_name, auth_token,
                 attributes, bundle_dl_location, result_callback, step_callback=None, lock_keeper=None):
        super(RaucDBUSDDIClient, self).__init__()

        self.attributes = attributes

        self.logger = logging.getLogger('rauc_hawkbit')
        self.ddi = DDIClient(session, host, ssl, auth_token, tenant_id, target_name)
        self.action_id = None
        self.app_config = None

        bundle_dir = os.path.dirname(bundle_dl_location)
        assert os.path.isdir(bundle_dir), 'Bundle directory must exist'
        assert os.access(bundle_dir, os.W_OK), 'Bundle directory not writeable'

        self.bundle_dl_location = bundle_dl_location
        self.lock_keeper = lock_keeper
        self.result_callback = result_callback
        self.step_callback = step_callback

        # DBUS proxy
        self.rauc = self.new_proxy('de.pengutronix.rauc.Installer', '/')

        # DBUS property/signal subscription
        self.new_property_subscription('de.pengutronix.rauc.Installer',
                                       'Progress', self.progress_callback)
        self.new_property_subscription('de.pengutronix.rauc.Installer',
                                       'LastError', self.last_error_callback)
        self.new_signal_subscription('de.pengutronix.rauc.Installer',
                                     'Completed', self.complete_callback)

    async def complete_callback(self, connection, sender_name, object_path,
                                interface_name, signal_name, parameters):
        """Callback for completion."""
        # bundle update was triggered from elsewhere
        if not self.action_id:
            return

        if self.lock_keeper:
            self.lock_keeper.unlock(self)

        result = parameters[0]
        os.remove(self.bundle_dl_location)
        status_msg = 'Rauc bundle update completed with result: {}'.format(
            result)
        self.logger.info(status_msg)

        # send feedback to HawkBit
        if result == 0:
            status_execution = DeploymentStatusExecution.closed
            status_result = DeploymentStatusResult.success
        else:
            status_execution = DeploymentStatusExecution.closed
            status_result = DeploymentStatusResult.failure

        await self.ddi.deploymentBase[self.action_id].feedback(
                status_execution, status_result, [status_msg])

        self.action_id = None

        self.result_callback(result)

    async def progress_callback(self, connection, sender_name,
                                object_path, interface_name,
                                signal_name, parameters):
        """Callback for changed Progress property."""
        # bundle update was triggered from elsewhere
        if not self.action_id:
            return

        percentage, description, nesting_depth = parameters
        self.logger.info('Update progress: {}% {}'.format(percentage,
                                                          description))

        if self.step_callback:
            self.step_callback(percentage, description)

        # send feedback to HawkBit
        status_execution = DeploymentStatusExecution.proceeding
        status_result = DeploymentStatusResult.none
        await self.ddi.deploymentBase[self.action_id].feedback(
                status_execution, status_result, [description],
                percentage=percentage)

    async def last_error_callback(self, connection, sender_name,
                                  object_path, interface_name,
                                  signal_name, last_error):
        """Callback for changed LastError property."""
        # bundle update was triggered from elsewhere
        if not self.action_id:
            return

        # LastError property might have been cleared
        if not last_error:
            return

        self.logger.info('Last error: {}'.format(last_error))

        # send feedback to HawkBit
        status_execution = DeploymentStatusExecution.proceeding
        status_result = DeploymentStatusResult.failure
        await self.ddi.deploymentBase[self.action_id].feedback(
                status_execution, status_result, [last_error])

    async def start_polling(self, wait_on_error=60):
        """Wrapper around self.poll_base_resource() for exception handling."""
        while True:
            try:
                await self.poll_base_resource()
            except asyncio.CancelledError:
                self.logger.info('Polling cancelled')
                break
            except asyncio.TimeoutError:
                self.logger.warning('Polling failed due to TimeoutError')
            except (APIError, TimeoutError, ClientOSError, ClientResponseError) as e:
                # log error and start all over again
                self.logger.warning('Polling failed with a temporary error: {}'.format(e))
            except Exception:
                self.logger.exception('Polling failed with an unexpected exception:')
            self.action_id = None
            self.logger.info('Retry will happen in {} seconds'.format(
                wait_on_error))
            await asyncio.sleep(wait_on_error)

    async def identify(self, base):
        """Identify target against HawkBit."""
        self.logger.info('Sending identifying information to HawkBit')
        # identify
        await self.ddi.configData(
                ConfigStatusExecution.closed,
                ConfigStatusResult.success, **self.attributes)

    async def cancel(self, base):
        self.logger.info('Received cancelation request')
        # retrieve action id from URL
        deployment = base['_links']['cancelAction']['href']
        match = re.search('/cancelAction/(.+)$', deployment)
        action_id, = match.groups()
        # retrieve stop_id
        stop_info = await self.ddi.cancelAction[action_id]()
        stop_id = stop_info['cancelAction']['stopId']
        # Reject cancel request
        self.logger.info('Rejecting cancelation request')
        await self.ddi.cancelAction[stop_id].feedback(
                CancelStatusExecution.rejected, CancelStatusResult.success, status_details=("Cancelling not supported",))

    async def install(self):
        if self.lock_keeper and not self.lock_keeper.lock(self):
            self.logger.info("Another installation is already in progress, aborting")
            return

        #self.rauc.Install('(s)', self.bundle_dl_location)
        self.logger.info("Installing the new Application")

        self.app_config = self.json_dump(APP_CONFIG_FILE)
        ret = self.install_app(self.app_config, self.bundle_dl_location)


        await self.finish_callback(result=ret)


    def json_dump(self, file_name=None):
        with open(file_name) as json_file:
            return json.load(json_file)


    def remove_bundle(self, cnfg=None, bundle=None):
        # Remove downloaded bundle
        """try:
            os.remove(bundle)
        except Exception as e:
            self.logger.error('Failed to delete %s. Reason: %s' % (bundle, e))"""


        # Remove unpacked bundle
        try:
            shutil.rmtree(cnfg["Update_Folder"])
        except Exception as e:
            self.logger.error('Failed to delete %s. Reason: %s' % (cnfg["Update_Folder"], e))

    def install_app(self, config=None, bundle_path=None):
        self.logger.info("bundle location: {}".format(bundle_path))

        # unpack the bundle

        bundle_location = str(config["Download_Path"]) + str("/") + str(config["Image_Name"])
        self.logger.info("Unpacking Application bundle file from {}".format(bundle_location))
        bundle_file = tarfile.open(bundle_location)
        bundle_file.extractall(path=str(config["Download_Path"]))
        bundle_file.close()


        # Version check
        """version = self.json_dump(str(config["Bin_path"]) + str("/") + str(config["app_version_file"]))
        self.logger.info(version)
        curr_version = version["version"]

        version = self.json_dump(str(config["Update_Folder"]) + str("/") + str(config["app_version_file"]))
        self.logger.info(version)
        new_version = version["version"]


        if curr_version != new_version:
            self.logger.info("New version is available. starting the Application upgrade process")
        else:
            self.logger.info("No new version is available. Skipping the Application upgrade process")
            self.remove_bundle(cnfg=self.app_config, bundle=bundle_location)
            return 1"""

        # Stopping the Application service
        try:
            cmd = str("systemctl stop ") + str(config["app_service"])
            os.popen(cmd)
            time.sleep(3)
            cmd = str("systemctl stop ") + str(config["app_service1"])
            os.popen(cmd)
            time.sleep(3)
            self.logger.info("Stopped the Application service")
        except OSError as ose:
            self.logger.error("Error while stopping application service")
            self.logger.exception(ose)
            self.remove_bundle(cnfg=self.app_config, bundle=bundle_location)
            return 1

        # Install the new Application
        # Copy new Application
        try:
            shutil.copytree(config["Update_Folder"], config["Bin_path"],dirs_exist_ok=True)
        except Exception as e:
            self.logger.error('Failed to copy %s into %s. Reason: %s' % (config["Update_Folder"], config["Bin_path"], e))
            self.remove_bundle(cnfg=self.app_config, bundle=bundle_location)
            # TODO: Restore the previous binaries
            return 1
        self.remove_bundle(cnfg=self.app_config, bundle=bundle_location)

        # Starting the Application service
        try:
            cmd = str("systemctl start ") + str(config["app_service"])
            os.popen(cmd)
            time.sleep(3)
            cmd = str("systemctl start ") + str(config["app_service1"])
            os.popen(cmd)
            time.sleep(3)
            self.logger.info("Started the Application service")
        except OSError as ose:
            self.logger.error("Error while starting application service")
            self.logger.exception(ose)

        self.logger.info("New Application upgrade is successful!")
        return 0


    async def finish_callback(self, result=1):
        """Callback for finishing RAUC install."""
        # bundle update was triggered from elsewhere
        self.logger.info("action_id: {}".format(self.action_id))
        if not self.action_id:
            self.logger.info("bundle update was triggered from elsewhere")
            return
        """if self.lock_keeper:
            self.lock_keeper.unlock(self)"""

        if result == 0:
            status_msg = 'Rauc bundle update completed with result: {}'.format("SUCCESS")
        else:
            status_msg = 'Rauc bundle update completed with result: {}'.format("FAIL")

        os.remove(self.bundle_dl_location)
        self.logger.info(status_msg)

        # send feedback to HawkBit
        if result == 0:
            status_execution = DeploymentStatusExecution.closed
            status_result = DeploymentStatusResult.success
        else:
            status_execution = DeploymentStatusExecution.closed
            status_result = DeploymentStatusResult.failure

        await self.ddi.deploymentBase[self.action_id].feedback(status_execution, status_result, [status_msg])

        self.action_id = None

        self.result_callback(result)



    async def process_deployment(self, base):
        """
        Check for deployments, download them, verify checksum and trigger
        RAUC install operation.
        """
        if self.action_id is not None:
            self.logger.info('Deployment is already in progress')
            return

        # retrieve action id and resource parameter from URL
        deployment = base['_links']['deploymentBase']['href']
        match = re.search('/deploymentBase/(.+)\?c=(.+)$', deployment)
        action_id, resource = match.groups()
        self.logger.info('Deployment found for this target')
        # fetch deployment information
        deploy_info = await self.ddi.deploymentBase[action_id](resource)
        try:
            chunk = deploy_info['deployment']['chunks'][0]
        except IndexError:
            # send negative feedback to HawkBit
            status_execution = DeploymentStatusExecution.closed
            status_result = DeploymentStatusResult.failure
            msg = 'Deployment without chunks found. Ignoring'
            await self.ddi.deploymentBase[action_id].feedback(
                    status_execution, status_result, [msg])
            raise APIError(msg)

        try:
            artifact = chunk['artifacts'][0]
        except IndexError:
            # send negative feedback to HawkBit
            status_execution = DeploymentStatusExecution.closed
            status_result = DeploymentStatusResult.failure
            msg = 'Deployment without artifacts found. Ignoring'
            await self.ddi.deploymentBase[action_id].feedback(
                    status_execution, status_result, [msg])
            raise APIError(msg)

        # prefer https ('download') over http ('download-http')
        # HawkBit provides either only https, only http or both
        if 'download' in artifact['_links']:
            download_url = artifact['_links']['download']['href']
        else:
            download_url = artifact['_links']['download-http']['href']

        # download artifact, check md5 and report feedback
        md5_hash = artifact['hashes']['md5']
        self.logger.info('Starting bundle download')
        await self.download_artifact(action_id, download_url, md5_hash)

        # download successful, start install
        self.logger.info('Starting installation')
        try:
            self.action_id = action_id
            # do not interrupt install call
            await asyncio.shield(self.install())
        except GLib.Error as e:
            # send negative feedback to HawkBit
            status_execution = DeploymentStatusExecution.closed
            status_result = DeploymentStatusResult.failure
            await self.ddi.deploymentBase[action_id].feedback(
                    status_execution, status_result, [str(e)])
            raise APIError(str(e))

    async def download_artifact(self, action_id, url, md5sum,
                                tries=3):
        """Download bundle artifact."""
        try:
            match = re.search('/softwaremodules/(.+)/artifacts/(.+)$', url)
            software_module, filename = match.groups()
            static_api_url = False
        except AttributeError:
            static_api_url = True

        if self.step_callback:
            self.step_callback(0, "Downloading bundle...")

        # try several times
        for dl_try in range(tries):
            if not static_api_url:
                checksum = await self.ddi.softwaremodules[software_module] \
                    .artifacts[filename](self.bundle_dl_location)
            else:
                # API implementations might return static URLs, so bypass API
                # methods and download bundle anyway
                checksum = await self.ddi.get_binary(url,
                                                     self.bundle_dl_location)

            if checksum == md5sum:
                self.logger.info('Download successful')
                return
            else:
                self.logger.error('Checksum does not match. {} tries remaining'
                                  .format(tries-dl_try))
        # MD5 comparison unsuccessful, send negative feedback to HawkBit
        status_msg = 'Artifact checksum does not match after {} tries.' \
            .format(tries)
        status_execution = DeploymentStatusExecution.closed
        status_result = DeploymentStatusResult.failure
        await self.ddi.deploymentBase[action_id].feedback(
                status_execution, status_result, [status_msg])
        raise APIError(status_msg)

    async def sleep(self, base):
        """Sleep time suggested by HawkBit."""
        sleep_str = base['config']['polling']['sleep']
        self.logger.info('Will sleep for {}'.format(sleep_str))
        t = datetime.strptime(sleep_str, '%H:%M:%S')
        delta = timedelta(hours=t.hour, minutes=t.minute, seconds=t.second)
        await asyncio.sleep(delta.total_seconds())

    async def poll_base_resource(self):
        """Poll DDI API base resource."""
        while True:
            base = await self.ddi()

            if '_links' in base:
                if 'configData' in base['_links']:
                    await self.identify(base)
                if 'deploymentBase' in base['_links']:
                    await self.process_deployment(base)
                if 'cancelAction' in base['_links']:
                    await self.cancel(base)

            await self.sleep(base)
