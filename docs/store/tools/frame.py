import sys, subprocess, html, os, tempfile
raw,out,W,H,t,sub=sys.argv[1],sys.argv[2],int(sys.argv[3]),int(sys.argv[4]),sys.argv[5],sys.argv[6]
r=subprocess.check_output(['magick','identify','-format','%w %h',raw]).decode().split()
rw,rh=int(r[0]),int(r[1]); u=W/1080
top=(70+64*1.2+14+36*1.3+50)*u; ih=H-top; iw=ih*rw/rh
land=rw>rh
if iw>W-80*u: iw=W-80*u; ih=iw*rh/rw
page=f'''<!doctype html><meta charset=utf-8><style>html,body{{margin:0;overflow:hidden;width:{W}px;height:{H}px}}
body{{background:#25422D;font-family:-apple-system,"Helvetica Neue",Arial,sans-serif;display:flex;flex-direction:column;align-items:center}}
h1{{margin:{70*u}px 0 0;font-size:{64*u}px;color:#fff;font-weight:700;letter-spacing:-.5px}}
p{{margin:{14*u}px 0 0;font-size:{36*u}px;color:#F2C14E}}
img{{margin-top:{50*u}px;width:{iw}px;height:{ih}px;border-radius:{(str(40*u)+'px') if land else (str(40*u)+'px '+str(40*u)+'px 0 0')};{'margin-top:'+str(max(50*u,(H-top-ih)/2-40*u))+'px;' if land else ''}box-shadow:0 10px 40px rgba(0,0,0,.45)}}</style>
<h1>{html.escape(t)}</h1><p>{html.escape(sub)}</p><img src="file://{raw}">'''
f=os.path.join(os.path.dirname(os.path.abspath(__file__)),'_frame.html'); open(f,'w').write(page)
subprocess.run(['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome','--headless=new','--disable-gpu','--hide-scrollbars','--allow-file-access-from-files','--force-device-scale-factor=1',f'--window-size={W},{H}',f'--screenshot={out}','file://'+f],capture_output=True)
subprocess.run(['magick',out,'-alpha','off',out])
