CREATE OR REPLACE TYPE "TRITEM"                                          as object
(
  itemName      varchar2(100),
  itemExt       varchar2(50),
  itemThrowDIR  varchar2(150),
  dc            clob,
  db            blob,
  dn            number,
  dv            varchar2(2000),
  dd            date,
  archPass      varchar2(100),
  dataType      number,
  sendMethod    number, -- 1=email, 2=ftp, 4=webdav!?

  member procedure addclob(p    clob),
  member procedure addblob(p    blob),
  member procedure addnumber(p  number),
  member procedure addstr(p     varchar2),
  member procedure addDate(p    date),

  member function GetDefaultName return varchar2,
  member function GetSize return number,
  member function PrintMe return varchar2,
  member function GetDataB(SELF IN OUT tritem, p_needArch number default null) return blob,
  member function GetDataV return varchar2,
  member function getMsisdnByRcpt(p_recip in varchar2, p_dayPart number default null) return varchar2,
  member procedure setItemThrowDir(p_dir in varchar2),
  member function getNameWOpath(SELF IN OUT tritem) return varchar2,

  
  static function iCreate(p clob,       -- сами данные
    pf      in varchar2 default null,   -- имя файла
    pe      in varchar2 default 'csv',  -- расширение файла
    ptd     in varchar2 default '',     -- директория на площадке пересылки либо одно из особых значений [aux]
    pass    in varchar2 default null,   -- паролья для архивации
    sm      in number   default 7       -- канал который может быть использован для пересылки
  ) return tritem,
    
  static function iCreate(p blob,   pf in varchar2 default null, 
    pe      in varchar2 default 'zip', 
    ptd     in varchar2 default '', 
    pass    in varchar2 default null,
    sm      in number   default 7) return tritem,
    
  static function iCreate(p number, pf in varchar2 default null, 
    pe      in varchar2 default 'txt', 
    ptd     in varchar2 default '', 
    pass    in varchar2 default null,
    sm      in number   default 7) return tritem,
    
  static function iCreate(p varchar2,pf in varchar2 default null,
    pe      in varchar2 default 'txt', 
    ptd     in varchar2 default '', 
    pass    in varchar2 default null,
    sm      in number   default 7) return tritem,
    
  static function iCreate(p date,   pf in varchar2 default null, 
    pe      in varchar2 default 'txt', 
    ptd     in varchar2 default '', 
    pass    in varchar2 default null,
    sm      in number   default 7) return tritem
)
 NOT FINAL;
/
CREATE OR REPLACE TYPE BODY "TRITEM"
as
------------------------------------------------------------------
  member procedure addclob(p clob) is 
  begin
    dc  := p;   self.dataType := self.dataType + 1;
  end;
  
  member procedure addblob(p blob) is
  begin
    db  := p;   self.dataType := self.dataType + 2;
  end;

  member procedure addnumber(p number) is
  begin
    dn  := p;   self.dataType := self.dataType + 4;
  end;

  member procedure addstr(p varchar2) is
  begin
    dv  := p;   
    self.dataType := self.dataType + 8;
  end;
  
  member procedure addDate(p date) is
    begin
    dd  := p;   
    self.dataType := self.dataType + 16;
  end;

------------------------------------------------------------------
  member function GetDefaultName return varchar2 is
  begin
    return 'job_'||sys_context('jm_ctx','job_id')||
           '_'||sys_context('jm_ctx','procedure')||
           '_'||to_char(sysdate,'yyyymmddhh24mi')||
           '_'||sys_context('userEnv','sid');
  end;

------------------------------------------------------------------
  member function GetSize return number
  is
  begin
    return 0+
      nvl(case when bitand(DataType,1)>0 then length(dc) end,0)+
      nvl(case when bitand(DataType,2)>0 then length(db) end,0)+
      nvl(case when bitand(DataType,4)>0 then length(dn) end,0)+
      nvl(case when bitand(DataType,8)>0 then length(dv) end,0)+
      nvl(case when bitand(DataType,16)>0 then length(dd) end,0);
  end;
  
------------------------------------------------------------------
  member function PrintMe return varchar2
  is
  begin
    return 
      itemName||'.'||itemExt||' '||'.'||itemThrowDir||' '||
      'datatype='||DataType||'('||
      case when bitand(DataType,1)>0 then '+clob' end||
      case when bitand(DataType,2)>0 then '+blob' end||
      case when bitand(DataType,4)>0 then '+number' end||
      case when bitand(DataType,8)>0 then '+varchar' end||
      case when bitand(DataType,16)>0 then '+date' end||') '||
      'size=('||GetSize||') '||
      'arch='||archPass;
  end;
  
------------------------------------------------------------------
member function getMsisdnByRcpt(p_recip in varchar2, p_dayPart number default null) return varchar2
is
  l_ans        varchar2(20):='';
  L_daypart    number;
begin
  begin
    if p_dayPart is not null then 
      L_daypart := 15;
    else
      L_daypart := case when sysdate between trunc(sysdate)+7/24 and trunc(sysdate)+9/24-1/86400   then 1
                        when sysdate between trunc(sysdate)+9/24 and trunc(sysdate)+18/24-1/86400  then 2
                        when sysdate between trunc(sysdate)+18/24 and trunc(sysdate)+22/24-1/86400 then 3
                        else 4 end;
    end if;
    execute immediate 'select msisdn from j_recipient_sms 
                       where lower(recipient)=lower(:rcpt) and enabled=1 and bitand(:ldp,daypart)>0 and rownum=1' 
            into l_ans using p_recip, L_daypart;
  exception
    when others then
      l_ans := '9282011384';
  end;
  return l_ans;
end; 
  
------------------------------------------------------------------
  member function GetDataB(SELF IN OUT tritem, p_needArch number default null) return blob
  is 
    lb blob;
    l_pass varchar2(100):= archPass;
  begin
    if nvl(p_needArch,0)=0 then 
      return db;
    else
      if bitand(DataType,1)>0 then 
        if length(archPass)>0 then
          lb := pck_zip.clob_aes_compress(dc, itemName||'.'||itemext, l_pass);
          self.archPass := l_pass;
        else  
          lb := pck_zip.clob_compress(dc, itemName||'.'||itemext);
        end if;
      end if;
      if bitand(DataType,2)>0 then 
        if length(archPass)>0 then
          lb := pck_zip.clob_aes_compress(dc, itemName||'.'||itemext, l_pass);
        else  
          lb := pck_zip.blob_compress(db, itemName||'.'||itemext);
        end if;
      end if;
      return lb;
    end if;
  end;
  
------------------------------------------------------------------
  member function GetDataV return varchar2
  is 
    l_str varchar2(1000) := '';
  begin
       if bitand(DataType,1+4+8+16)>0 then 
         l_str := itemName||'= ';
         l_str := l_str || case when bitand(DataType,4)>0  then to_char(dn)||', ' end;
         l_str := l_str || case when bitand(DataType,8)>0  then dv         ||', ' end;
         l_str := l_str || case when bitand(DataType,16)>0 then to_char(dd, 'dd/mm/yyyy hh24:mi:ss')||', ' end;
         l_str := l_str || case when bitand(DataType,1)>0  then 
                                                           case when length(dc)>50 then substr(dc,1,50)||'...(первые 50 символов), ' 
                                                                else to_char(dc) end
                           end;
         l_str := substr(l_str, 1, length(l_str)-2);
       end if;
     return l_str;
  end;

------------------------------------------------------------------
  member procedure setItemThrowDir(p_dir in varchar2)
  is
    l_str   varchar2(200) := p_dir;
  begin
   if length(p_dir)=0 then 
     return;
   end if;
    if substr(l_str,1,1) in ('/','\') then 
      l_str := substr(l_str,2,length(l_str)-1);
    end if;
    if substr(l_str, length(l_str),1)in ('/','\') then 
      l_str := substr(l_str, 1, length(l_str)-1);
    end if;
    self.itemThrowDir := l_str;
  end;

------------------------------------------------------------------
member function getNameWOpath(SELF IN OUT tritem) return varchar2
is
  l_pos  number;
begin
  l_pos := instr(replace(self.itemName,'\','/'),'/',-1);
  return case when l_pos>0 then substr(self.itemName,l_pos+1) else self.itemName end;
end;
    
------------------------------------------------------------------
  static function iCreate(p clob,       -- сами данные
    pf      in varchar2 default null,   -- имя файла
    pe      in varchar2 default 'csv',  -- расширение файла
    ptd     in varchar2 default '',     -- директория на площадке пересылки либо одно из особых значений [aux]
    pass    in varchar2 default null,   -- паролья для архивации
    sm      in number   default 7       -- канал который может быть использован для пересылки
  ) return tritem
  is
    ti tritem;
  begin
    ti := tritem
    (itemName => pf,
     itemExt  => nvl(pe,'csv'),
     itemThrowDir  => nvl(ptd,''),
     dc => p,
     db => null,
     dn => null,
     dv => null,
     dd => null,
     archPass => nvl(pass,''),
     dataType => 1,
     sendMethod => case when sm >7 then 7 else sm end
     );
     if pf is null then ti.itemName := ti.GetDefaultName; end if;
     ti.SetItemThrowDir(ptd);
     return ti;
  end;
  
------------------------------------------------------------------
  static function iCreate(p blob, 
    pf      in varchar2 default null,   -- имя файла
    pe      in varchar2 default 'zip',  -- расширение файла
    ptd     in varchar2 default '',     -- директория на площадке пересылки либо одно из особых значений [aux]
    pass    in varchar2 default null,   -- паролья для архивации
    sm      in number   default 7       -- канал который может быть использован для пересылки
  ) return tritem
  is
    ti tritem;
  begin
    ti := tritem
    (itemName => nvl(pf,sys_context('userEnv','sid')||'_'||sys_context('jm_ctx','author')),
     itemExt  => nvl(pe,'zip'),
     itemThrowDir  => nvl(ptd,''),
     dc => null,
     db => p,
     dn => null,
     dv => null,
     dd => null,
     archPass => nvl(pass,''),
     dataType => 2,
     sendMethod => case when sm >7 then 7 else sm end
     );
     if pf is null then ti.itemName := ti.GetDefaultName; end if;
     ti.SetItemThrowDir(ptd);
     return ti;
  end;

------------------------------------------------------------------
  static function iCreate(p number, 
    pf      in varchar2 default null,   -- имя файла
    pe      in varchar2 default 'txt',  -- расширение файла
    ptd     in varchar2 default '',     -- директория на площадке пересылки либо одно из особых значений [aux]
    pass    in varchar2 default null,   -- паролья для архивации
    sm      in number   default 7       -- канал который может быть использован для пересылки
  ) return tritem
  is
    ti tritem;
  begin
    ti := tritem
    (itemName => nvl(pf,sys_context('userEnv','sid')||'_'||sys_context('jm_ctx','author')),
     itemExt  => nvl(pe,'txt'),
     itemThrowDir  => nvl(ptd,''),
     dc => null,
     db => null,
     dn => p,
     dv => null,
     dd => null,
     archPass => nvl(pass,''),
     dataType => 4,
     sendMethod => case when sm >7 then 7 else sm end
     );
     if pf is null then ti.itemName := ti.GetDefaultName; end if;
     ti.SetItemThrowDir(ptd);
     return ti;
  end;

------------------------------------------------------------------
  static function iCreate(p varchar2, 
    pf      in varchar2 default null,   -- имя файла
    pe      in varchar2 default 'txt',  -- расширение файла
    ptd     in varchar2 default '',     -- директория на площадке пересылки либо одно из особых значений [aux]
    pass    in varchar2 default null,   -- паролья для архивации
    sm      in number   default 7       -- канал который может быть использован для пересылки
  ) return tritem
  is
    ti tritem;
  begin
    ti := tritem
    (itemName => nvl(pf,sys_context('userEnv','sid')||'_'||sys_context('jm_ctx','author')),
     itemExt  => nvl(pe,'txt'),
     itemThrowDir  => nvl(ptd,''),
     dc => null,
     db => null,
     dn => null,
     dv => p,
     dd => null,
     archPass => nvl(pass,''),
     dataType => 8,
     sendMethod => case when sm >7 then 7 else sm end
     );
     if pf is null then ti.itemName := ti.GetDefaultName; end if;
     ti.SetItemThrowDir(ptd);
     return ti;
  end;

------------------------------------------------------------------
  static function iCreate(p date,
    pf      in varchar2 default null,   -- имя файла
    pe      in varchar2 default 'txt',  -- расширение файла
    ptd     in varchar2 default '',     -- директория на площадке пересылки либо одно из особых значений [aux]
    pass    in varchar2 default null,   -- паролья для архивации
    sm      in number   default 7       -- канал который может быть использован для пересылки
  ) return tritem
  is
    ti tritem;
  begin
    ti := tritem
    (itemName => nvl(pf,sys_context('userEnv','sid')||'_'||sys_context('jm_ctx','author')),
     itemExt  => nvl(pe,'txt'),
     itemThrowDir  => nvl(ptd,''),
     dc => null,
     db => null,
     dn => null,
     dv => null,
     dd => p,
     archPass => nvl(pass,''),
     dataType => 16,
     sendMethod => case when sm >7 then 7 else sm end
     );
     if pf is null then ti.itemName := ti.GetDefaultName; end if;
     ti.SetItemThrowDir(ptd);
     return ti;
  end;

end;
/
