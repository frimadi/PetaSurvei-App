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
s = re.sub(r'android:label="[^"]*"', 'android:label="Survei Jalan"', s, count=1)
open(p, 'w', encoding='utf-8').write(s)
print('Manifest diperbarui')
