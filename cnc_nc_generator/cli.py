from __future__ import annotations
import argparse
from pathlib import Path
from .native_nc import NCParameters,SUPPORTED_PROFILES,generate_nc
def build_parser():
 p=argparse.ArgumentParser(description='Generate SKG1625 NC natively (Excel is not required).');p.add_argument('profile',choices=SUPPORTED_PROFILES)
 p.add_argument('--tool-diameter',type=float,default=94.4);p.add_argument('--tool-width',type=float,default=24.3);p.add_argument('--thickness',type=float,default=19);p.add_argument('--work-offset',default='G58');p.add_argument('--x-correction',type=float,default=0);p.add_argument('--y-correction',type=float,default=0);p.add_argument('--roughing-feed',type=int,default=1000);p.add_argument('--finishing-feed',type=int,default=2000);p.add_argument('--program-number',default='O0001');p.add_argument('-o','--output',type=Path);return p
def main(argv=None):
 a=vars(build_parser().parse_args(argv));out=a.pop('output');nc=generate_nc(NCParameters(**a))
 if out:out.write_text(nc,encoding='utf-8')
 else:print(nc,end='')
 return 0
if __name__=='__main__':raise SystemExit(main())
