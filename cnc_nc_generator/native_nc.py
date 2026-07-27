"""Native translation of the SKG1625 NC workbook formulas."""
from __future__ import annotations
from dataclasses import dataclass

# slope, intercept, sign, optional correction (17 coordinate pairs x four cuts)
E={
'129-122-03-210':[(.414214,-5,-1,''),(.08284,352,1,'h'),(.05858,5,1,''),(.0791,108.12179,1,'y'),(.05662,5.64571,1,''),(.04972,4.95813,-1,''),(.08226,352.08373,-1,'x'),(.01071,45.85267,1,''),(.06803,4.95813,-1,''),(.05974,4.35429,-1,''),(.08669,155.26588,-1,'y'),(0,0,1,''),(.05858,5,1,''),(.05858,5,-1,''),(.05858,5,1,''),(0,0,1,''),(0,0,1,'')],
'129-122-03-102':[(.414214,-5,-1,''),(.08793,386.41309,1,'h'),(.05994,4.15153,1,''),(.07844,231.7593,1,'y'),(.04565,5.5367,1,''),(.04791,5.81121,-1,''),(.07755,344.88384,-1,'x'),(.00952,42.33704,1,''),(.06747,4.96275,-1,''),(.05969,4.39079,-1,''),(.08646,275.16974,-1,'y'),(.01351,39.90682,-1,''),(.07114,4.92748,1,''),(.05858,5,-1,''),(.05858,5,1,''),(0,0,1,''),(0,0,1,'')],
'129-122-03-211':[(.414214,-5,-1,''),(.08284,352,1,'h'),(.05858,5,1,''),(.08088,168.16505,1,'y'),(.05766,5.33578,1,''),(.05391,4.98871,-1,''),(.08269,352.02257,-1,'x'),(.00556,23.69383,1,''),(.06341,4.98871,-1,''),(.05929,4.66422,-1,''),(.08482,192.53043,-1,'y'),(0,0,1,''),(.05858,5,1,''),(.05858,5,-1,''),(.05858,5,1,''),(0,0,1,''),(0,0,1,'')]}
SUPPORTED_PROFILES=tuple(E)
@dataclass(frozen=True,slots=True)
class NCParameters:
 profile:str; tool_diameter:float=94.4; tool_width:float=24.3; thickness:float=19.; work_offset:str='G58'; x_correction:float=0.; y_correction:float=0.; roughing_feed:int=1000; finishing_feed:int=2000; program_number:str='O0001'
 def __post_init__(self):
  if self.profile not in E: raise ValueError(f'Unsupported profile {self.profile!r}; choose {", ".join(E)}')
  if min(self.tool_diameter,self.tool_width,self.thickness)<=0: raise ValueError('Dimensions must be positive')
  if not self.work_offset.startswith('G5'): raise ValueError('work_offset must be a G5x coordinate system')
def _n(v):
 if abs(float(v))<5e-12:v=0
 return f'{float(v):.8f}'.rstrip('0').rstrip('.').replace('.',',')
def _geometry(p):
 takes=(p.tool_diameter/2+1.5,p.tool_diameter/2+.4,p.tool_diameter/2+.2,p.tool_diameter/2)
 corr={'':0,'h':p.x_correction/2,'x':p.x_correction,'y':p.y_correction}
 return [[sgn*(m*t*(1 if i==0 else 10)+b+corr[c]) for t in takes] for i,(m,b,sgn,c) in enumerate(E[p.profile])]
def generate_nc(p:NCParameters)->str:
 """Return the complete program; no workbook or cached output is accessed."""
 n=_n;r=p.tool_diameter/2;d=(p.tool_width-p.thickness)/2+p.thickness
 starts=[-(t+p.y_correction/2) for t in (r+1.5,r+.4,r+.2,r)];g=_geometry(p)
 q=['%',p.program_number,f'(PART NAME/NUMBER:{p.profile}/ THK {n(p.thickness)}MM/PERIMETER)',f'(TOOL:ØX{n(p.tool_diameter)}MM/THK{n(p.tool_width)}MM)',f'S{5500 if p.tool_diameter<110 else 3800}M03','G90G40G49G80G98',f'G21G00{p.work_offset}G17','T01M06','G90G00G43Z50,0H01',f'G90G00X{n(-r)}Y{n(-r-10)}','Z10,0',f'G01Z{n(-d)}F3000','',f'G01X{n(-r)}Y{n(starts[0])}F{p.roughing_feed}','']
 for cut in range(4):
  feed=p.roughing_feed if cut<2 else p.finishing_feed
  q += [f'G90G01X{n(g[0][cut])}Y{n(starts[cut])}Z{n(-d)}'+(f'F{feed}' if cut else ''),f'G91G01X{n(g[1][cut])}Y{n(g[15][cut])}Z0,3',f'X{n(g[2][cut])}Y{n(g[12][cut])}',f'X{n(g[11][cut])}Y{n(g[3][cut])}',f'X{n(g[5][cut])}Y{n(g[4][cut])}',f'X{n(g[6][cut])}Y{n(g[7][cut])}Z-0,3',f'X{n(g[8][cut])}Y{n(g[9][cut])}',f'X{n(g[16][cut])}Y{n(g[10][cut])}',f'X{n(g[14][cut])}Y{n(g[13][cut])}','']
 q += q[-10:] # workbook repeats the fourth finishing pass
 q += ['X5,0Y-5,0','','G90G00X-60,0Y-60,0','Z50,0','X-400,0Y300,0','M05','M09','G49','M30','%']
 return '\n'.join(q)+'\n'
