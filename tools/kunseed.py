#!/usr/bin/env python3
"""Exports the Mac KUNLIGHT (moonlight-qt) PC list, pairing identity and
orders into ~/.kunlight/ios-seed/kunseed.json. The iOS build copies that
file into the app, which imports it on launch, so the phone starts out
paired with every PC the Mac knows. The file holds the client private key:
it stays outside the repo and only goes into apps built on this Mac."""
import base64, hashlib, json, os, plistlib, subprocess, tempfile

prefs = plistlib.loads(subprocess.run(
    ['defaults', 'export', 'com.moonlight-stream.Moonlight', '-'],
    check=True, capture_output=True).stdout)

def openssl(*args, data=None):
    return subprocess.run(['openssl', *args], input=data, check=True, capture_output=True).stdout

cert = prefs['certificate']
key = prefs['key']
key_trad = openssl('rsa', '-traditional', data=key)
with tempfile.TemporaryDirectory() as d:
    open(os.path.join(d, 'c.pem'), 'wb').write(cert)
    open(os.path.join(d, 'k.pem'), 'wb').write(key)
    # iOS reads the p12 with the stock "limelight" password; legacy 3DES keeps it readable
    p12 = openssl('pkcs12', '-export', '-in', os.path.join(d, 'c.pem'), '-inkey', os.path.join(d, 'k.pem'),
                  '-passout', 'pass:limelight', '-keypbe', 'PBE-SHA1-3DES', '-certpbe', 'PBE-SHA1-3DES', '-macalg', 'sha1')

hosts = []
for i in range(1, prefs.get('hosts.size', 0) + 1):
    g = lambda k, dflt=None: prefs.get(f'hosts.{i}.{k}', dflt)
    if not g('uuid') or not g('srvcert'):
        continue  # not paired on the Mac
    apps = []
    for j in range(1, g('apps.size', 0) + 1):
        a = lambda k, dflt=None: prefs.get(f'hosts.{i}.apps.{j}.{k}', dflt)
        apps.append((a('order', -1), str(a('name', '')), str(a('id', ''))))
    ordered = [aid for o, n, aid in sorted(apps, key=lambda t: (t[0] < 0, t[0], t[1].lower()))]
    mac = g('mac') or b''
    hosts.append({
        'uuid': g('uuid'),
        'name': g('hostname'),
        'address': g('manualaddress') or g('localaddress') or g('remoteaddress'),
        'localAddress': g('localaddress') or None,
        'externalAddress': g('remoteaddress') or None,
        'mac': ':'.join(f'{b:02X}' for b in mac) if len(mac) == 6 else None,
        # iOS pins the server certificate as DER
        'serverCert': base64.b64encode(openssl('x509', '-outform', 'DER', data=g('srvcert'))).decode(),
        'appOrder': ordered if any(o >= 0 for o, _, _ in apps) else [],
    })

seed = {
    'uniqueId': prefs['uniqueid'],
    'cert': base64.b64encode(cert).decode(),
    'key': base64.b64encode(key_trad).decode(),
    'p12': base64.b64encode(p12).decode(),
    'hosts': hosts,
    'pcOrder': list(prefs.get('pcOrder', [])),
}
seed['version'] = hashlib.sha256(json.dumps(seed, sort_keys=True).encode()).hexdigest()[:16]

out = os.path.expanduser('~/.kunlight/ios-seed')
os.makedirs(out, mode=0o700, exist_ok=True)
path = os.path.join(out, 'kunseed.json')
with open(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), 'w') as f:
    json.dump(seed, f)
print(f'{path}: {len(hosts)} PCs, version {seed["version"]}')
