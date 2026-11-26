import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
izin = '''    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
'''
if 'android.permission.CAMERA' not in s:
    s = s.replace('<application', izin + '    <application', 1)
if 'WRITE_EXTERNAL_STORAGE' not in s:   # penyimpanan galeri di Android 9 ke bawah (paket gal)
    s = s.replace('<application', '    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29"/>\n    <application', 1)
if 'requestLegacyExternalStorage' not in s:   # album galeri di Android 10
    s = s.replace('<application', '<application android:requestLegacyExternalStorage="true"', 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="Survei Jalan"', s, count=1)
open(p, 'w', encoding='utf-8').write(s)
print('Manifest diperbarui')
