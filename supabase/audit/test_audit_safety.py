"""Regression checks for audit-only capabilities and isolated recovery binding."""
import json
import os
from pathlib import Path
import re
import sys
import tempfile
import unittest
from unittest.mock import patch
import backup_metadata
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'staging'))
import recovery_validation as recovery

class AuditSafetyTests(unittest.TestCase):
    def test_production_queries_are_single_select_without_mutating_functions(self):
        for path in Path(__file__).parent.glob('*-select.sql'):
            sql=path.read_text().strip()
            self.assertTrue(sql.lower().startswith('select '))
            self.assertEqual(sql.count(';'),1)
            self.assertTrue(sql.endswith(';'))
            self.assertIsNone(re.search(r'\b(insert|update|delete|drop|alter|create|truncate|copy|call|do|set|grant|revoke|pg_terminate_backend|pg_read_file|lo_import|dblink|http_post)\b',sql,re.I))
    def test_backup_endpoint_is_metadata_get_only(self):
        self.assertEqual(backup_metadata.URL,'https://api.supabase.com/v1/projects/skngodvomygvxemfaefn/database/backups')
        with self.assertRaises(ValueError):backup_metadata.NoRedirect().redirect_request(None,None,None,None,None,None)
    def test_no_token_does_not_contact_network(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.dict(os.environ,{},clear=True),patch.object(backup_metadata,'__file__',str(Path(directory)/'metadata.py')),patch.object(backup_metadata.urllib.request,'build_opener') as opener:
                backup_metadata.main()
                opener.assert_not_called()
                self.assertEqual(json.loads((Path(directory)/'backup-metadata-result.json').read_text())['status'],'unverified')
    def test_recovery_rest_rejects_public_binding(self):
        d={'Config':{'Labels':{'maskan.validation':recovery.st.PROJECT}},'NetworkSettings':{'Networks':{recovery.st.RECOVERY_NETWORK:{}}},'HostConfig':{'PortBindings':{'3000/tcp':[{'HostIp':'0.0.0.0','HostPort':'57321'}]}}}
        with patch.object(recovery.st,'db_guard'),patch.object(recovery.st,'inspect',return_value=d):
            with self.assertRaises(ValueError):recovery.rest_guard()

if __name__=='__main__':unittest.main()
