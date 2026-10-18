"""Read only backup inventory. Never downloads backups or follows redirects."""
import json
import os
from pathlib import Path
import urllib.request
import urllib.error

URL = 'https://api.supabase.com/v1/projects/skngodvomygvxemfaefn/database/backups'

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        raise ValueError('Backup metadata redirects are forbidden')

def main():
    token = os.environ.get('SUPABASE_ACCESS_TOKEN')
    result = {'status': 'unverified', 'reason': 'No management token available; no backup was accessed'}
    if token:
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
        request = urllib.request.Request(URL, headers={'Authorization': 'Bearer '+token}, method='GET')
        try:
            with opener.open(request, timeout=20) as response:
                data = json.load(response)
            # Never retain signed URLs, credentials, or arbitrary response fields.
            result = {'status': 'metadata_read', 'pitr_enabled': data.get('pitr_enabled'),
                      'backup_count': len(data.get('backups', []))}
            result['backups'] = [{k: b.get(k) for k in ('inserted_at','status','is_physical_backup')}
                                 for b in data.get('backups', [])]
        except urllib.error.HTTPError as error:
            result = {'status': 'unverified', 'http_status': error.code}
    target = Path(__file__).with_name('backup-metadata-result.json')
    target.write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(result))

if __name__ == '__main__':
    main()
