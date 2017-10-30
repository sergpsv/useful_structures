CREATE OR REPLACE TYPE "TJOB"
as object
(
  job_id              number        ,
  job_name            varchar2(100),
  nextdat             DATE          ,
  nextformula         varchar2(1000)  ,
  maxnextdat          date          ,
  param1              VARCHAR2(100)  ,
  param2              VARCHAR2(100)  ,
  param3              VARCHAR2(100)  ,
  sendOnlyAnswerable  NUMBER        ,
  LastStart           date          ,
  run_by_job          NUMBER        ,
  maxParallel         number        ,
  job_comment         VARCHAR2(500) ,
  MAP MEMBER FUNCTION GetJobID RETURN NUMBER,
  member function GetNextDate  return date,
  -- get strvalue
  member function LastStart_str return varchar2,
  member function nextdat_str   return varchar2,
  member function GetRecipientList  return TStringList
)
/
CREATE OR REPLACE TYPE BODY "TJOB"
as
  -- для сортировок
  map member function GetJobID return number
  is
  begin
    return job_id;
  end GetJobID;

  member function GetNextDate  return date
  is
    dat date := null;
    l_interval varchar2(255) := replace(upper(nextformula),':NEXTDAT','to_date('''||to_char(nextdat,'dd.mm.yyyy hh24:mi:ss')||''',''dd.mm.yyyy hh24:mi:ss'')');
  begin
    IF nextformula IS NOT NULL THEN
      execute immediate 'select '||l_interval ||' from dual' into dat;
      if dat<nextdat then
        raise_application_Error(-20000, 'Дата после вычисления интервала меньше прошлого запуска');
      end if;
    end if;
    return dat;
  end;

  member function LastStart_str return varchar2
  is
  begin
    return 
       case 
          when laststart is null then 'null' 
       else 
          'to_date('''||to_char(laststart,'dd.mm.yyyy hh24:mi:ss')||''',''dd.mm.yyyy hh24:mi:ss'')' 
    end;
  end;

  member function nextdat_str return varchar2
  is
  begin
    return 
       case 
          when nextdat is null then 'null' 
       else 
          'to_date('''||to_char(nextdat,'dd.mm.yyyy hh24:mi:ss')||''',''dd.mm.yyyy hh24:mi:ss'')' 
    end;
  end;

  member function GetRecipientList  return TStringList
  is
    ts  TStringList := TStringList();
--    job number := 2;
  begin
    if self.sendOnlyAnswerable = 1 then 
      for i in (select recipient from j_recipient j where j.job_id = self.job_id and answerable=1)
      loop
        ts.extend; ts(ts.count):=i.recipient; 
      end loop;
    else
      for i in (select recipient from j_recipient j where j.job_id = self.job_id and nvl(enabled,0)=1
              and nvl(MAXSENDDATE,to_date('31.12.2999'))>sysdate )
      loop
        ts.extend;
        ts(ts.count):=i.recipient; 
      end loop;
    end if;    
    if ts.count=0 then ts.extend; ts(1) := '<sergey.parshukov@megafonkavkav.ru>'; end if;
    /*for i in ts.first .. ts.last 
    loop
      dbms_output.put_line(ts(i));
    end loop; */
    return ts;
  end;
  
end;
-- End of DDL Script for Type DEPSTAT.TJOB

-- Start of DDL Script for Type DEPSTAT.TMAIL
-- Generated 21/04/2008 10:43:01 from DEPSTAT@VORONDB
/
