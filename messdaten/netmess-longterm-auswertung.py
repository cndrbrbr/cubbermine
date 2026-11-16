import sys,re,glob,os,statistics as st
from datetime import datetime,timedelta
d=sys.argv[1]
for f in sorted(glob.glob(d+'/*.log')):
    name=os.path.basename(f)[:-4]
    blocks=[];cur=None;other=[]
    for line in open(f):
        m=re.match(r'===== (\S+) =====',line)
        if m:
            cur={'t':datetime.fromisoformat(m.group(1)),'rtt':[],'tx':None,'rx':None};blocks.append(cur);continue
        m=re.search(r'time=([\d.]+) ms',line)
        if m: cur['rtt'].append(float(m.group(1)));continue
        m=re.match(r'(\d+) packets transmitted, (\d+) received',line)
        if m: cur['tx'],cur['rx']=int(m.group(1)),int(m.group(2));continue
        if line.strip() and not line.startswith(('PING','---','rtt','\n')): other.append(line.strip())
    tx=sum(b['tx'] or 0 for b in blocks); rx=sum(b['rx'] or 0 for b in blocks)
    r=[x for b in blocks for x in b['rtt']]; rs=sorted(r)
    q=lambda p: rs[min(len(rs)-1,int(p*len(rs)))]
    gaps=[(blocks[i-1]['t'],blocks[i]['t']) for i in range(1,len(blocks)) if (blocks[i]['t']-blocks[i-1]['t']).total_seconds()>75]
    lossb=[b for b in blocks if b['tx'] and b['rx']<b['tx']]
    mdevs=[st.pstdev(b['rtt']) for b in blocks if len(b['rtt'])>1]
    ipdv=[abs(b['rtt'][i]-b['rtt'][i-1]) for b in blocks for i in range(1,len(b['rtt']))]
    # day (07-23) vs night
    day=[x for b in blocks if 7<=b['t'].hour<23 for x in b['rtt']]; night=[x for b in blocks if not 7<=b['t'].hour<23 for x in b['rtt']]
    hourly={}
    for b in blocks: hourly.setdefault(b['t'].hour,[]).extend(b['rtt'])
    worsth=max(hourly,key=lambda h: st.mean(hourly[h]))
    blkavg=[st.mean(b['rtt']) for b in blocks if b['rtt']]
    print(f"{name}: {blocks[0]['t']}..{blocks[-1]['t']} blocks={len(blocks)} tx={tx} rx={rx} loss={100*(tx-rx)/tx:.4f}% lossblocks={len(lossb)} {[ (b['t'].isoformat(),b['tx']-b['rx']) for b in lossb][:10]}")
    print(f"  min={rs[0]:.3f} avg={st.mean(r):.3f} med={q(.5):.3f} p99={q(.99):.3f} p999={q(.999):.3f} max={rs[-1]:.3f} sd={st.pstdev(r):.3f} mean_blockmdev={st.mean(mdevs):.3f} max_blockmdev={max(mdevs):.3f} ipdv={st.mean(ipdv):.3f}")
    print(f"  >2ms={sum(x>2 for x in r)} >5ms={sum(x>5 for x in r)} >10ms={sum(x>10 for x in r)} >30ms={sum(x>30 for x in r)} blkavg_max={max(blkavg):.3f} at {blocks[blkavg.index(max(blkavg))]['t']}")
    print(f"  day avg={st.mean(day):.3f} night avg={st.mean(night):.3f} worst hour={worsth} avg={st.mean(hourly[worsth]):.3f} best hour avg={min(st.mean(v) for v in hourly.values()):.3f}")
    print(f"  gaps>75s={gaps[:5]} n={len(gaps)} other={other[:5]} nother={len(other)}")
    top=sorted(((x,b['t']) for b in blocks for x in b['rtt']),reverse=True)[:5]
    print("  top:",[(f"{x:.1f}",t.strftime('%d.%m %H:%M')) for x,t in top])
