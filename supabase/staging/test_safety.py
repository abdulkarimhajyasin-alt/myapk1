import os
import json
import unittest
from unittest.mock import patch
import staging

class SafetyTests(unittest.TestCase):
    def test_production_and_other_projects_fail_before_docker(self):
        with patch.object(staging, 'docker_guard') as docker:
            for project in [staging.PRODUCTION, 'myapkprojekt', 'maskan-hardening-local', staging.PROJECT+'-other']:
                with self.assertRaises(ValueError): staging.target_guard(project=project)
            docker.assert_not_called()

    def test_only_exact_loopback_api_is_allowed(self):
        with patch.object(staging, 'docker_guard') as docker:
            for url in ['https://'+staging.PRODUCTION+'.supabase.co', 'http://127.0.0.1:55321',
                        'http://127.0.0.1:54321', 'http://127.0.0.1:56321@evil.invalid',
                        'http://localhost:56321', staging.API+'/', 'https://127.0.0.1:56321']:
                with self.assertRaises(ValueError): staging.target_guard(url=url)
            docker.assert_not_called()

    def test_remote_docker_override_is_rejected(self):
        with patch.dict(os.environ, {'DOCKER_HOST': 'tcp://example.invalid:2376'}):
            with patch.object(staging, 'run') as command:
                with self.assertRaises(ValueError): staging.docker_guard()
                command.assert_not_called()

    def test_remote_named_pipe_is_rejected(self):
        with patch.dict(os.environ, {'DOCKER_HOST':'npipe:////remote-server/pipe/docker_engine'}):
            with patch.object(staging,'run') as command:
                with self.assertRaises(ValueError):staging.docker_guard()
                command.assert_not_called()

    def test_mutating_cloud_cli_commands_are_not_exposed(self):
        with patch.object(staging, 'target_guard'):
            for action in ['db', 'link', 'deploy', 'projects', 'migration']:
                with self.assertRaises(ValueError): staging.cli(action)

    def test_function_deploy_is_rejected(self):
        with patch.object(staging, 'target_guard'), patch.object(staging, 'run') as command:
            with self.assertRaises(ValueError): staging.cli('functions','deploy')
            command.assert_not_called()

    def test_redirects_are_rejected(self):
        with self.assertRaises(ValueError):
            staging.NoRedirect().redirect_request(None,None,None,None,None,None)

    def test_public_database_binding_is_rejected(self):
        data={'Config':{'Labels':{'maskan.validation':staging.PROJECT}},
              'Mounts':[{'Destination':'/var/lib/postgresql/data','Name':'supabase_db_'+staging.PROJECT}],
              'NetworkSettings':{'Networks':{staging.NETWORK:{}}},
              'HostConfig':{'PortBindings':{'5432/tcp':[{'HostIp':'0.0.0.0','HostPort':'56322'}]}}}
        with patch.object(staging,'target_guard'),patch.object(staging,'inspect',return_value=data):
            with self.assertRaises(ValueError):staging.db_guard()

    def test_container_labels_are_required(self):
        with patch.object(staging, 'target_guard'), patch.object(staging, 'inspect', return_value={'Config': {'Labels': {}}}):
            with self.assertRaises(ValueError): staging.db_guard()

if __name__ == '__main__': unittest.main()
