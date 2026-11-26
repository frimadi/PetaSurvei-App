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
if 'WRITE_EXTERNAL_STORAGE' not in s:   # penyimpanan galeri sampai Android 10 (paket gal)
    # Plugin kamera sudah mendeklarasikan izin ini dengan maxSdkVersion=28; kita timpa ke 29.
    if 'xmlns:tools=' not in s:
        s = s.replace('<manifest', '<manifest xmlns:tools="http://schemas.android.com/tools"', 1)
    s = s.replace('<application', '    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29" tools:replace="android:maxSdkVersion"/>\n    <application', 1)
if 'requestLegacyExternalStorage' not in s:   # album galeri di Android 10
    s = s.replace('<application', '<application android:requestLegacyExternalStorage="true"', 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="Survei Jalan"', s, count=1)
open(p, 'w', encoding='utf-8').write(s)
print('Manifest diperbarui')
