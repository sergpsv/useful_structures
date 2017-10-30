CREATE SEQUENCE idanytable_seq
  INCREMENT BY 1
  START WITH 1
/

CREATE OR REPLACE 
TYPE tadvreport as object
(
    result       number,
    result_txt   varchar2(500),
    job_id       number,
    msgSubject   varchar2(200),
    msgbody      clob,
    rl           TRItemList,
    sl           TRItemList,
    
    -- private debug
    member procedure l_debug(str in varchar2) ,
    member procedure l_printStatus, -- return number,
    member procedure l_printStatus(self in out tadvReport, l_list in TSTringList, p_listName in varchar2),
    -- private 
    member function GetConst(p_what in varchar2) return varchar2,
    member function isEmail(self in out tadvReport, p_str in out varchar2) return number,
    member function isFTP(p_str in out varchar2) return number,
    member function GetAnswerAble(self in out tadvReport, p_job_id number, p_mode number) return TStringList,
    member function SaveToTab(p_chanel in varchar2, p_recipList TStringList, p_err varchar2) return number,
 
    member function GetOneRecip(p_recip in varchar2, 
            p_fHost in out varchar2, p_fLogin in out varchar2, 
            p_fPass in out varchar2, p_fPath in out varchar2) return number,
    member function GetScripts(self in out tadvReport, p_adr in varchar2) return TRItemList,
    
    --public
    -- 1 конструктор пустого отчета - пустой
    static function rCreate(p_res in number, p_res_txt in varchar2) return TADVREPORT,
    -- 2 конструктор пустого отчета - ссылка на джоб
    static function rCreate(p_res in number, p_res_txt in varchar2, p_report in number) return TADVREPORT,
    -- 3
    static function rCreate(p_res in number, p_res_txt in varchar2, p_report in number,
                            p_rl      in TRItemList) return TADVREPORT,
    -- 4
    static function rCreate(p_res in number, p_res_txt in varchar2, p_report in number,
                            p_Subject in varchar,
                            p_body    in clob) return TADVREPORT,
    -- 5 
    static function rCreate(p_res in number, p_res_txt in varchar2, p_report in number,
                            p_Subject in varchar,
                            p_body    in clob,
                            p_rl      in TRItemList) return TADVREPORT,
    -- 6
    static function rCreate(p_res in number, p_res_txt in varchar2, p_report in number,
                            p_Subject in varchar,
                            p_body    in clob,
                            p_rl      in TRItemList,
                            p_sl      in TRItemList) return TADVREPORT,
    -- отправка отчета через отчетную систему
member function PushLtoFTP(self in out tadvReport,   p_Whatlist     TStringList,                       -- кому отправляем
  p_FileList  in TRItemList,                        -- что отправляем
  p_needArch  in number      default 0,             -- архивировать отправляемое?
  p_codepage  in varchar2    default 'CL8MSWIN1251',-- кодировка при передаче текстовых данных
  p_throwMode in number      default 0              -- режим "через площадку"
) return number,

member function SendReport(self in out tadvReport) return number,
member function SendThrow(self in out TADVREPORT, p_List TStringList, p_needArch in number default 0) return number
)
/

-- Grants for Type
GRANT EXECUTE ON tadvreport TO sparshukov
/

CREATE OR REPLACE 
TYPE BODY tadvreport
as

-------------------------------------------------------------
member function GetConst(p_what in varchar2) return varchar2
is
  l_what varchar2(100) := trim(lower(p_what));
begin
  return case 
    when l_what = 'mymsisdn'   then '9282011384'
    when l_what = 'myemail'    then 'sergey.parshukov@megafon.ru'
    when l_what = 'myftp'      then 'ftp_user:ftp21gfcc!@10.23.23.175'
    when l_what = 'defaultftp' then 'ftp://login:password@ipaddress_or_sitename'
  else
    ''
  end;
end;

-------------------------------------------------------------
  -- конструктор 1
  static function rCreate(p_res in number, p_res_txt in varchar2) return TADVREPORT
  is
  begin
    return TADVREPORT(p_res, p_res_txt, 
        nvl(sys_context('jm_ctx','job_id'),-1), 
        'Статистика: '||to_char(sysdate,'dd.mm.yyyy')||' - '||sys_context('jm_ctx','procedure'),
        to_clob(''), 
        null, null);
  end ;
  
-------------------------------------------------------------
  -- конструктор 2
  static function rCreate(p_res in number, p_res_txt in varchar2, p_report in number) return TADVREPORT
  is
    l_comm varchar2(2000);
  begin
    begin
      execute immediate 'select job_comment from j_list where job_id = :j' 
        into l_comm using p_report;
    exception
      when others then l_comm := '';
    end;
    return TADVREPORT(p_res, p_res_txt, 
      p_report, 
      'Статистика: '||to_char(sysdate,'dd.mm.yyyy')||' - '||sys_context('jm_ctx','procedure'),
      to_clob(l_comm),
      null, null
      );
  end ;
  
-- 4 -----------------------------------------------------------
  static function rCreate(p_res in number, p_res_txt in varchar2, p_report in number,p_Subject in varchar,p_body    in clob) return TADVREPORT
  is
  begin
    return TADVREPORT(p_res, p_res_txt, p_report, 
      p_subject,
      p_body,
      null, 
      null
      );
  end;

-------------------------------------------------------------
  static function rCreate(p_res in number, p_res_txt in varchar2, p_report in number, p_rl in TRItemList) return TADVREPORT
  is
    l_comm varchar2(2000);
  begin
    begin
      execute immediate 'select job_comment from j_list where job_id = :j' 
        into l_comm using p_report;
    exception
      when others then l_comm := '';
    end;
    return TADVREPORT(p_res, p_res_txt, 
      p_report, 
      'Статистика: '||to_char(sysdate,'dd.mm.yyyy')||' - '||sys_context('jm_ctx','procedure'),
      to_clob(l_comm),
      p_rl, 
      null
      );
  end;
  
-------------------------------------------------------------
-- конструктор пустого отчета - максимальный
  static function rCreate(p_res in number, p_res_txt in varchar2, p_report in number,
                            p_Subject in varchar,
                            p_body    in clob,
                            p_rl      in TRItemList,
                            p_sl      in TRItemList) return TADVREPORT
  is
  begin
    return tadvreport(
      p_res, 
      p_res_txt, 
      p_report,
      p_subject,
      p_body,
      p_rl,
      p_sl
    );
  end;
-------------------------------------------------------------
-- конструктор пустого отчета - максимальный
  static function rCreate(p_res in number, p_res_txt in varchar2, p_report in number,
                            p_Subject in varchar,
                            p_body    in clob,
                            p_rl      in TRItemList) return TADVREPORT
  is
  begin
    return tadvreport(
      p_res, 
      p_res_txt, 
      p_report,
      p_subject,
      p_body,
      p_rl,
      null
    );
  end;
  

--------------------------------------------------------------
    member procedure l_debug(str in varchar2)
    is begin
      dbms_output.put_line(str/*||chr(10)||chr(13)*/);
      log_ovart(0, 'tadvrep', str);
    end;
    
--------------------------------------------------------------
    member procedure l_printStatus --return number
    is 
      l_res number;
    begin
    dbms_output.put_line('result='||result);
    dbms_output.put_line('result_txt='||result_txt);
    dbms_output.put_line('job_id='||job_id);
    dbms_output.put_line('msgSubject='||msgSubject);
    dbms_output.put_line('msgbody=('||msgbody||')');
    if rl is not null then 
      dbms_output.put_line('attachemts - '||rl.count);
      for i in rl.first .. rl.last
      loop
        dbms_output.put_line(i||') '||rl(i).PrintMe);
      end loop;
    end if;
    end;
--------------------------------------------------------------
    member procedure l_printStatus(self in out tadvReport, l_list in TSTringList, p_listName in varchar2)
    is 
      l number;
    begin
      if l_list is not null and l_list.count>0 then 
        for i in l_list.first .. l_list.last
        loop
          if i=l_list.first then l_debug('LIST ('||p_listName||') :------- '||l_list.count); end if;
          --l_debug('('||l_list(i)||')');
        end loop;
      else
        l_debug('LIST ('||p_listName||') :------- empty'); 
      end if;
    end;

--------------------------------------------------------------
member function isEmail(self in out tadvReport, p_str in out varchar2) return number
is 
 ltemp number; 
begin
 p_str := trim(p_str);
 if p_str like 'mailto:%' then 
   p_str := substr(p_str,8);
 end if;
 if p_str like '<%>' then 
   p_str := substr(p_str, 2, length(p_str)-2);
 end if;
 if p_str like '%:%@%' then 
   return -1; -- probable ftp
 elsif lower(p_str) not like '%@%.%' then 
   l_debug('looks not like email "'||p_str||'"');
   return -1;
 else
   return 1; -- success
 end if;
end;

--------------------------------------------------------------
member function isFTP(p_str in out varchar2) return number
is 
 l_res number :=0;
 ltemp number; 
begin
 p_str := trim(p_str);
 if p_str like 'ftp://%' then 
   p_str := substr(p_str,7);
 end if;
 if p_str not like '%:%@%.%' then 
   return -1; -- probable email
 else
   return 1; -- success
 end if;
end;

--------------------------------------------------------------
member function GetAnswerAble(self in out tadvReport, p_job_id number, p_mode number) return TStringList
is
  l_list    TStringList := TStringList();
begin
  begin
    if p_mode = 3 then 
      l_list.extend; l_list(l_list.count) := GetConst('myEmail');
    else
        for i in (select RECIPIENT from j_recipient where job_id = self.job_id and answerable=1)
        loop
          if isEmail(i.RECIPIENT)=1 and p_mode=1 then l_list.extend; l_list(l_list.count) := i.RECIPIENT;    end if;
          if isFtp(i.RECIPIENT)=1   and p_mode=2 then l_list.extend; l_list(l_list.count) := GetConst('defaultftp')||'/Answerable/job_'||to_char(self.job_id); end if;
        end loop;
    end if;
  exception
    when others then
      l_list.extend; l_list(l_list.count) := GetConst('myEmail');
    end;
  return l_list;
end; 


--------------------------------------------------------------
    -- вложенная функция (не удается вызвать как член класса-member procedure)  
    member function SaveToTab(p_chanel in varchar2, p_recipList TStringList, p_err varchar2) return number
    is
      l_job_id  number        := sys_context('jm_ctx','job_id');
      l_info    varchar2(100) := sys_context('UserEnv','client_info');
      l_author  varchar2(100) := lower(sys_context('jm_ctx','author'));
      l_res     number;
    begin
      select count(1) into l_res from user_tables where table_name = 'NOT_SENDED_REPORT';
      ------------------------------------------------------------
      if l_res =0 then 
        execute immediate 'create table not_sended_Report
                         (chanel      varchar2(100),
                          job_id      number,
                          client_info varchar2(100),
                          author      varchar2(100),
                          recipients  TSTringList,
                          RIList      TRItemList,
                          navi_date   date          default sysdate,
                          sid         number        default sys_context(''userenv'',''sid''),
                          error_msg   varchar2(1000),
                          iid         number,
                          processed   number
                         )
                         nested table recipients store as not_sended_Report_recipients return as value
                         nested table RIList     store as not_sended_Report_RIList     return as value';
         execute immediate '                         
            CREATE OR REPLACE TRIGGER not_sended_Report_rid
             BEFORE INSERT ON not_sended_Report
            REFERENCING NEW AS NEW OLD AS OLD
             FOR EACH ROW
            begin
              select idanytable_seq.nextval into :new.iid from dual;
            end;';
                                 
        execute immediate 'comment on table not_sended_Report is ''Вложения не отправленные объектом TADVREPOT по причине err_msg''';
      end if;

      ------------------------------------------------------------
      execute immediate 'insert into not_sended_Report(chanel, job_id, client_info, author, Recipients, RIList, error_msg) 
                                               values (:chnl, :job_id,:client_info,:author,:Recipients, :rc,    :error_msg)'
                                             using p_chanel, l_job_id, l_info,  l_author, p_recipList, rl, p_err;
                l_res := l_res + 1;
      commit;
      return 0;
    end; -- конец вложенной функции SaveToTab


--------------------------------------------------------------
member function GetOneRecip(p_recip in varchar2, 
            p_fHost in out varchar2, p_fLogin in out varchar2, 
            p_fPass in out varchar2, p_fPath in out varchar2) return number
is
    l_str varchar2(500) := replace(p_recip,'\','/');
begin
    if upper(p_recip) like 'FTP://%' then 
      l_str := substr(l_str, 7);
    else
      l_str := l_str;
    end if;
    -- 'FTP://dealer_upload:bKB8pTPc@10.23.10.234'
    p_fLogin := substr(l_str, 1, instr(l_str,':')-1);
    p_fPass  := substr(l_str, 1+instr(l_str,':') , instr(l_str,'@')-1-length(substr(l_str, 1, instr(l_str,':'))));
    if instr(l_str,'/') > 0 then 
        p_fhost  := substr(l_str, 1+instr(l_str,'@') , instr(l_str,'/')-1-length(substr(l_str, 1, instr(l_str,'@'))));
        p_fPath  := substr(l_str, 1+instr(l_str,'/') );
    else
        p_fhost  := substr(l_str, 1+instr(l_str,'@'));
        p_fPath  := '';
    end if;
    if length(p_fHost)>0 and length(p_fLogin)>0 and length(p_fPass)>0 then 
      return 1;
    else
      return -1;
    end if;
end;

--------------------------------------------------------------
member function GetScripts(self in out tadvReport, p_adr in varchar2) return TRItemList
is
  L_src     varchar2(32000);
  d         varchar2(2)   := chr(10)||chr(13); 
  l_fHost   varchar2(100); 
  l_fLogin  varchar2(100);
  l_fPass   varchar2(100); 
  l_fPath   varchar2(100);
  ll        TRItemList := TRItemList(); 
  l_dir     varchar2(200);
  l_file    varchar2(200);
begin
  if GetOneRecip(p_adr, l_fHost ,l_fLogin ,l_fPass ,l_fPath )=-1 then
    l_debug('передан адрес не FTP вида');
    return ll;
  end if;
  if sl is not null and nvl(sl.count,0)>0 then 
    l_debug('В отчете умный человек уже вложил скрипты. Вносим их в список первыми.');
    ll := sl;
    for s in ll.first .. ll.last
    loop
      ll(s).itemname := 'j'||job_id||'_inrep_'||ll(s).itemname;
    end loop;
  end if;
  for i in (select PARAM_NAME, THROWSCRIPT from j_list_add_param where job_id=self.job_id and lower(part)='scripts' and enabled=1 order by PARAM_NAME)
  loop
    l_debug('в j_list_add_param обнаружен скрипт '||i.PARAM_NAME||' ('||length(i.THROWSCRIPT)||')');
    ll.extend;
    ll(ll.count) := TRItem.iCreate(i.THROWSCRIPT, 'j'||job_id||'_addp_'||substr(i.PARAM_NAME,1,instr(i.PARAM_NAME,'.')-1), substr(i.PARAM_NAME,instr(i.PARAM_NAME,'.')+1) );
  end loop;
  if nvl(ll.count,0) >0 then 
    l_debug('есть скрипты от пользователя, автоматическую генерацию производить не буду');
    return ll;
  end if;
  for i in rl.first .. rl.last
  loop
    if bitand(rl(i).sendMethod,2)>0 then 
      l_dir := substr(rl(i).itemName, 1, instr(rl(i).itemName,'\',-1)-1);
      l_file:= rl(i).getNameWOpath;--substr(rl(i).itemName, instr(rl(i).itemName,'\',-1)+1);
      l_src := '';
      l_src := l_src||'#!/bin/bash'||d;
      l_src := l_src||'# Переменные окружения'||d;
      l_src := l_src||'. /home/autoreport/scripts/env-vars'||d;
      l_src := l_src||'# Подключаю shell-функции'||d;
      l_src := l_src||'. /home/autoreport/scripts/functions'||d;
      l_src := l_src||'# Установка журналирования'||d;
      l_src := l_src||'logfile="$(basename $0).$(date +''%Y%m%d%H%M%S'').log"'||d;
      l_src := l_src||'exec 3>>"$LOGDIR/$logfile"'||d;
      l_src := l_src||'exec 2> >(stderr_log)'||d;
      l_src := l_src||'verbosity=$dbg_lvl'||d;
    
      l_src := l_src||'notify "start"'||d;
      l_src := l_src||'# Функция вернет 0, если все скопировалось, 1 - в противном случае (l_fPath='||l_fPath||')'||d;
      l_src := l_src||'ftpcp_to '||l_fHost||' '||l_fLogin||' '||l_fPass||' '||
                      '"'||case when length(l_fPath)<>0 then l_fPath else l_dir end||'" '||
                      '"'||l_file||'.'||rl(i).itemExt||'"'||d;
      l_src := l_src||'# Возвращаемое значение'||d;
      l_src := l_src||'ftpcp_res=$?'||d;
      l_src := l_src||'debug "ftpcp_to exited with $ftpcp_res"'||d;
      l_src := l_src||'notify "done"'||d;
      l_src := l_src||'# Выход с кодом возврата'||d;
      l_src := l_src||'exit $ftpcp_res'||d;
      ll.extend;
      ll(ll.count) := TRItem.iCreate(to_clob(l_src), 'j'||to_char(job_id)||'_auto_script_'||i, 'sh');
      l_debug('автоматом сделал скрипт "'||ll(ll.count).ItemName||'.sh"');
    end if;
  end loop;
  return ll;
end;

-------------------------------------------------------------
member function PushLtoFTP(self in out tadvReport, 
  p_Whatlist     TStringList,                       -- кому отправляем
  p_FileList  in TRItemList,                        -- что отправляем
  p_needArch  in number      default 0,             -- архивировать отправляемое?
  p_codepage  in varchar2    default 'CL8MSWIN1251',-- кодировка при передаче текстовых данных
  p_throwMode in number      default 0              -- режим "через площадку"
) return number
is 
  l_ftpList     TStringList     := p_Whatlist;
  ri            TRItem;
  l_errmsg      varchar2(2000);
  l_conn        UTL_TCP.connection;
  l_str         varchar2(1000);
  l_needArch    number          := p_needArch;
  l_res         number;
  l_filename    varchar2(500);
begin
  -- по всем адресатам
  for j in l_ftpList.first .. l_ftpList.last
  loop
      begin
        l_conn := ftp.login( l_ftpList(j) );
        --l_debug('adr: after login');
        --ftp.gpv_debug := true;
        for i in p_FileList.first .. p_FileList.last
        loop
          ri := p_FileList(i);
          l_filename := case when p_throwMode=0 then ri.itemName else ri.getNameWOpath end;
          if bitand(ri.DataType, 4+8+16)>0 and bitand(ri.sendMethod,2)>0 then 
            --l_debug('обнаружен отчет типа NUMBER or DATE or VARCHAR. конвертирую эти данные в CLOB тип');
            ri.addclob(ri.GetDataV);
          end if;
          if bitand(ri.DataType,1+2)>0 and bitand(ri.sendMethod,2)>0 then 
            if l_needArch=1 or bitand(ri.DataType,2)in(1,2,3) then 
              ftp.put_remote_binary_data(l_conn, l_filename||'.'||case when l_needArch=1 then 'zip' else ri.itemExt end, ri.GetDataB(l_needArch));
            elsif bitand(ri.DataType,1)=1 then 
              ftp.put_remote_ascii_data(l_conn, l_filename||'.'||ri.ItemExt, ri.dc, p_codepage);    
              --l_debug('adr: after put_remote_ascii_data('||l_filename||') size='||length(ri.dc));
            end if;
            if l_needArch=1 and ri.archPass<>'' and sys_context('jm_ctx','dont_send_password')is null then 
              l_str := ri.getMsisdnByRcpt(l_ftpList(j));
              utils.SendSms(l_str, 'пароль к архиву "'||l_filename||'.zip" : '||ri.archPass);
              --l_debug('adr: after sendSMS');
            end if;
          end if;
        end loop;
        ftp.logout(l_conn);
        --l_debug('adr: after logout');
        update j_recipient 
          set lastsend = sysdate 
        where job_id = self.job_id
          and (upper(trim(RECIPIENT)) in (select upper('FTP://'||COLUMN_VALUE) from table(cast(l_ftpList as TStringList)))
               or
               upper(trim(RECIPIENT)) in (select upper(COLUMN_VALUE) from table(cast(l_ftpList as TStringList))));
      commit;
      exception
        when others then
          l_errmsg  := dbms_utility.format_error_stack()||chr(13)||chr(10)||dbms_utility.format_error_backtrace();
          l_res := SaveToTab('ftp', l_ftpList, l_errmsg);
          return -1;
      end;
  end loop; -- по всем адресатам одного файла
  return 1;
end;

--------------------------------------------------------------
  /* отправка отчета через отчетную систему
  -1    nothing to send
  -2    TRItemList exists, but empty
  */
member function SendReport(self in out tadvReport) return number
is 
  l_cnt        number   :=0;
  l_res        number   :=0;
  l_answList   TStringList := TStringList();
  l_emailList  TStringList := TStringList();
  l_ftpList    TStringList := TStringList();
  type TRefCursor is ref cursor;
  c_cur        TRefCursor;
  l_str        varchar2(1000);
  l_only       number;
  l_needArch   number;
  l_msgBody    clob := self.msgBody;
  l_blb        blob;
  l_conn       UTL_TCP.connection;
  l_errmsg     varchar2(2000);
  l_THROW      number;
  THROW_list   TStringList := TStringList();
  ri           TRItem;
  
begin
    if rl is null  then return -1; end if;
    if rl.count =0 then return -2; end if;
    -- по любому нужен в подписи
    l_answList := GetAnswerAble(self.job_id, 1);
    if l_answList.count=0 then l_answList := GetAnswerAble(self.job_id, 2); end if;
    if l_answList.count=0 then l_answList := GetAnswerAble(self.job_id, 3); end if;
    -- Подготовка списков рассылки
    if self.job_id <> -1 then 
      execute immediate 'select count(1), sum(nvl(SENDONLYANSWERABLE,0)), sum(nvl(need_arch,0))
                         from j_list where job_id = :p'
                         into l_cnt, l_only, l_needarch using self.job_id;
      if (l_cnt = 1) and (l_only =0) then 
        -- есть в джобе нормальная отправка
        open c_cur for 'select recipient, nvl(THROW,0) THROW from j_recipient 
                        where job_id = :p and nvl(enabled,0)=1 and nvl(MAXSENDDATE,to_date(''31/12/2999''))>sysdate' using self.job_id;
        loop
          fetch c_cur into l_str, l_THROW;
          exit when c_cur%notfound;
          if l_THROW>0 then 
            THROW_list.extend(1);   THROW_list(THROW_list.count) := l_str; 
          else
            if isEmail(l_str)=1 then l_emailList.extend(1); l_emailList(l_emailList.count) := l_str;end if;
            if isFTP(l_str)=1   then l_ftpList.extend(1);   l_ftpList(l_ftpList.count) := l_str; end if;
          end if;
        end loop;
      end if;
    end if;
    
    if (l_cnt = 0) or (l_emailList.count=0 and l_ftpList.count=0 and THROW_list.count=0) then 
      l_emailList := TstringList(GetConst('myEmail'));
    end if;
    if (l_only >= 1) then 
      l_emailList := GetAnswerAble(self.job_id, 1);
      l_ftpList   := GetAnswerAble(self.job_id, 2);
      if l_msgBody is null then 
        dbms_lob.createtemporary(l_msgBody, false);
      end if;
      dbms_lob.append(l_msgBody, to_clob(chr(13)||chr(10)||' ---- отчет назначен на ответственного. Ниже список получателей в плановом режиме:'||chr(13)||chr(10) ));
      dbms_lob.append(l_msgBody, get_clob('select RECIPIENT from j_recipient where nvl(enabled,0)=1 
         and job_id = '||self.job_id||' and nvl(MAXSENDDATE,to_date(''31/12/2999'',''dd/mm/yyyy''))>sysdate order by RECIPIENT',false));
      dbms_lob.append(l_msgBody, to_clob('---- конец списка -----'||chr(13)||chr(10) ));
    end if;

    ---------------------------------------------------------------------------------------------------------
    -- отправляем данные по адресам FTP
    if l_ftpList is not null and l_ftpList.count>0 and rl is not null and rl.count>0 then 
      --L_PrintStatus(l_ftpList, 'l_ftpList');
      l_res := PushLtoFTP(l_ftpList, rl, l_needArch);
    end if;

    ---------------------------------------------------------------------------------------------------------
    -- отправляем данные по адресам EMAIL
    if l_emailList is not null and l_emailList.count>0 then 
      j_manager.ctx_set('footer1','Ваши вопросы по отчету (job_id = '||to_char(self.job_id)||') Вы можете направлять по адреcу '||l_answList(l_answList.first));
      begin
          --L_PrintStatus(l_emailList, 'l_emailList');
          if rl is not null and rl.count>=1 then 
            execute immediate 'begin :res := emailsender.SendEmailWithAttach(:l_emailList, :msgSubject, :l_msgBody, :rl, case when :l_needArch=1 then true else false end); end;' 
            using out l_res, in l_emailList, msgSubject,l_msgBody, rl, l_needArch;    
          else
            execute immediate 'begin :l_res := emailsender.SendEmailWithAttach(l_emailList, msgSubject,l_msgBody); end;'
            using out l_res, in l_emailList, msgSubject, l_msgBody;    
          end if;
          update j_recipient 
             set lastsend = sysdate 
           where job_id = self.job_id
             and (upper('<'||trim(RECIPIENT)||'>') in (select upper(COLUMN_VALUE) from table(cast(l_emailList as TStringList)))
                or
                 upper(trim(RECIPIENT)) in (select upper(COLUMN_VALUE) from table(cast(l_emailList as TStringList))));
          commit;
      exception
        when others then
          l_errmsg  := dbms_utility.format_error_stack()||chr(13)||chr(10)||dbms_utility.format_error_backtrace();
          l_res := SaveToTab('email', l_emailList, l_errmsg);
      end;
    end if;
    

    ---------------------------------------------------------------------------------------------------------
    if nvl(THROW_list.count,0)>0 and nvl(rl.count,0)>=0 then 
      l_printStatus(THROW_list, 'THROW_list');
      if SendThrow(THROW_list, l_needArch)<>1 then 
        null;
        l_debug('Ошибка при отправке на площадку '||l_throw);
      end if;
    end if;
    
    return 1;
exception 
  when others then 
    l_errmsg  := dbms_utility.format_error_stack()||chr(13)||chr(10)||dbms_utility.format_error_backtrace();
    log_ovart(-1, 'TADVREPORT', l_errmsg);
    return sqlcode;
end;

-- p_List : список реальных аресов, на которые должны быть отправлены файлы из RL (report list)
member function SendThrow(self in out TADVREPORT, p_List TStringList, p_needArch in number default 0) return number
is
  l_connStr  varchar2(200);
  l_datad    varchar2(200);
  l_scrd     varchar2(200);
  l_auxd     varchar2(200);
  l_codep    varchar2(200);
  l_cnt      number;
  l_errmsg   varchar2(2000);
  l_dir      varchar2(200);
  l_throw    number;
  scrList    TRItemList;
  l_needArch number := p_needArch;
begin
  --
  if nvl(p_list.count,0)=0 then 
    l_debug('список площадок для отправки пуст');
    return -1; 
  end if;
  for t in p_List.first .. p_list.last
  loop
      execute immediate 'select nvl(max(throw),0) throw from j_recipient where job_id = :j and recipient = :r' into l_throw using self.job_id, p_list(t);
      -- проверяем наличие площадки и берем ее параметры
      execute immediate 'select count(1), max(connStr), max(dataDir), max(SrcDir), max(auxDir), max(codepage) from j_throw
      where tid = :t and nvl(enabled,0)<>0'
               into l_cnt, l_connStr, l_datad, l_scrd, l_auxd, l_codep
               using l_throw;
      if l_cnt=0 then 
        l_debug('передан указатель('||l_throw||') на несуществующую площадку (j_recipient.throw)');
        continue;
      else
        -- чтобы не было проблем cо слешами в именах 
        if substr(l_connStr, 1 , length(l_connStr)) in ('/','\') then l_connStr := substr(l_connStr,1,length(l_connStr)-1); end if;
        if substr(l_datad, 1 , 1) in ('/','\') then l_datad := substr(l_datad, 2, l_datad-1);end if;
        if substr(l_scrd,  1 , 1) in ('/','\') then l_scrd  := substr(l_scrd,  2, l_scrd-1); end if;
        if substr(l_auxd,  1 , 1) in ('/','\') then l_auxd  := substr(l_auxd,  2, l_auxd-1); end if;
        --l_debug('директория данных=('||l_datad||') , скриптов=('||l_scrd||')');
      end if;
    
      -- передаем данные в директорю "dataDir" на площадке
      l_cnt := PushLtoFTP(TSTringList(l_connStr||'/'||l_datad), rl, l_needArch, p_throwMode=>1);
      -- передаем скрипты в директорию "SrcDir" на площадке
      if l_cnt=1 then 
        if PushLtoFTP(TSTringList(l_connStr||'/'||l_scrd), GetScripts(p_list(t)), 0, l_codep, p_throwMode=>1)<>1 then 
           l_debug('Ошибка при передаче скриптов');
           return -2;
        end if;
      end if;
      
  end loop;
  return 1;
end;


end;
------------------------------------------------------------
/

-- Start of DDL Script for Type Body TRANSFORMER.TFTPRECORD
-- Generated 14/10/2014 11:04:43 from TRANSFORMER@DWHKVK
CREATE OR REPLACE 
TYPE tftprecord
as object
(
  recipList       TstringList,
  filenames       TStringList,
  files           TClobList,
  IsArch          number,
  ArchPass        varchar2(50),
  member function GetOneRecip(/*self in out tftprecord,*/p_recip in varchar2, 
            p_fHost in out varchar2, p_fLogin in out varchar2, 
            p_fPass in out varchar2, p_fPath in out varchar2)return number,
  member procedure SetRecipients(p_recip in varchar2) ,
  member procedure SetRecipients(p_recip in TStringList default null) ,
  member function SendReport return number,
  static function ftpCreate(p_filenames TstringList, p_files TclobList, p_isArch number default 0) return TftpRecord
)
/

-- Grants for Type
GRANT EXECUTE ON tftprecord TO rkrikunov
/
GRANT EXECUTE ON tftprecord TO skhizhnjak
/
GRANT EXECUTE ON tftprecord TO sparshukov
/
GRANT EXECUTE ON tftprecord TO ldwh
/

CREATE OR REPLACE 
TYPE BODY tftprecord
as
  ------------------------------------------------------------------------
  -- author = sparshukov
  ------------------------------------------------------------------------
  -- конструктор - все элементы объекта нужно инициализировать для простоты работы с ними в дальнейшем
  static function ftpCreate(p_filenames TstringList, p_files TclobList, p_isArch number default 0) return TftpRecord
  is
  begin
    return TftpRecord(TstringList(), p_filenames, p_files, p_isArch, '');
  end;

  ------------------------------------------------------------------------
  -- получение одного хоста
  member function GetOneRecip(/*self in out tftprecord,*/p_recip in varchar2, 
            p_fHost in out varchar2, p_fLogin in out varchar2, 
            p_fPass in out varchar2, p_fPath in out varchar2) return number
  is
    l_str varchar2(500) := replace(p_recip,'\','/');
  begin
    if upper(p_recip) like 'FTP://%' then 
      l_str := substr(l_str, 7);
    else
      l_str := l_str;
    end if;
    -- 'FTP://dealer_upload:bKB8pTPc@10.23.10.234'
    p_fLogin := substr(l_str, 1, instr(l_str,':')-1);
    p_fPass  := substr(l_str, 1+instr(l_str,':') , instr(l_str,'@')-1-length(substr(l_str, 1, instr(l_str,':'))));
    if instr(l_str,'/') > 0 then 
        p_fhost  := substr(l_str, 1+instr(l_str,'@') , instr(l_str,'/')-1-length(substr(l_str, 1, instr(l_str,'@'))));
        p_fPath  := substr(l_str, 1+instr(l_str,'/') );
    else
        p_fhost  := substr(l_str, 1+instr(l_str,'@'));
        p_fPath  := '';
    end if;
    if length(p_fHost)>0 and length(p_fLogin)>0 and length(p_fPass)>0 then 
      return 1;
    else
      return -1;
    end if;
  end;

  ------------------------------------------------------------------------
  -- установка списка хостов
  member procedure SetRecipients(p_recip in varchar2) 
  Is
  begin
    SetRecipients(TStringList(p_recip));
  end;
  
  ------------------------------------------------------------------------
  -- установка списка хостов
  member procedure SetRecipients(p_recip in TStringList default null)
  is
    ts     TStringList := TStringList();
    rs     number;
    usr    varchar2(100);
    ftpadr varchar2(100); 

    fhost   varchar2(255);
    fLogin  varchar2(255);
    fPass   varchar2(255);
    fPath   varchar2(500);
 begin
    if p_recip is not null then 
      if p_recip.count=0 then 
         SetRecipients;
      end if;
      -- проверка переданного списка е-майлов на вшивость по маске
      for i in p_recip.first .. p_recip.last
      loop
        --select count(1) into rs from (select p_recip(i) ftpadr from dual) where ftpadr like '%:%@%';
        rs := GetOneRecip(p_recip(i),fhost,fLogin,fPass,fPath);
        if rs=1 then 
          ts.extend;
          ts(ts.count) := p_recip(i);
        else
          dbms_output.put_line('адрес : '||p_recip(i)||' не прошел контроль на валидность для FTP');
        end if;
      end loop;
      recipList := ts;
      
    else 
      usr := lower(sys_context('jm_ctx','author'));
      if usr not in ('sparshukov', 'rkrikunov', 'skhizhnjak', 'rvasin', 'vasin_rs', 'drastvorov', 'rastvorov_db') 
         or usr is null
      then 
        execute immediate 'select lower(case when user in (''DEPSTAT'',''TRANSFORMER'', ''LDWH'') then osuser else osuser end) usr from v$session where sid=sys_context(''userenv'',''sid'')' into usr;
      end if;
      ftpadr := case when usr='sparshukov'   then 'ftp://ftpuser:ftp21gfcc@10.61.24.210/sparshukov'
                     when usr='rkrikunov'    then 'ftp://ftpuser:ftp21gfcc@10.61.24.210/rkrikunov'
                     when usr='skhizhnjak'   then 'ftp://ftpuser:ftp21gfcc@10.61.24.210/skhizhnjak'
                     when usr='rvasin'       then 'ftp://ftpuser:ftp21gfcc@10.61.24.210/rvasin'
                     when usr='vasin_rs'     then 'ftp://ftpuser:ftp21gfcc@10.61.24.210/rvasin'
                     when usr='drastvorov'   then 'ftp://ftpuser:ftp21gfcc@10.61.24.210/drastvorov'
                     when usr='rastvorov_db' then 'ftp://ftpuser:ftp21gfcc@10.61.24.210/drastvorov'
                end; 
      recipList := TStringList( ftpadr );
    end if;
  end;
  
/*  ------------------------------------------------------------------------
  -- отправка отчетов
  member procedure SaveToTab(p_fname varchar2, p_file clob, p_err varchar2)
  is
    l_job_id  number        := sys_context('jm_ctx','job_id');
    l_info    varchar2(100) := sys_context('UserEnv','client_info');
    l_author  varchar2(100) := lower(sys_context('jm_ctx','author'));
    l_recips  varchar2(1000):='';  
  begin
    null;
  end;
*/

  ------------------------------------------------------------------------
  -- отправка отчетов
  member function SendReport return number
  is
    l_conn  UTL_TCP.connection;
    l_b     blob;
    fhost   varchar2(255);
    fLogin  varchar2(255);
    fPass   varchar2(255);
    fPath   varchar2(500);
    l_syst  varchar2(100);

    l_sendres number        := 0; -- результат работы функции (0-успех, <0 - ошибка)
    l_errmsg  varchar2(1000):='';    
  
    -- вложенная функция (не удается вызвать как член класса-member procedure)  
    procedure SaveToTab(p_recip varchar2, p_fname varchar2, p_file clob, p_err varchar2)
    is
      l_job_id  number        := sys_context('jm_ctx','job_id');
      l_info    varchar2(100) := sys_context('UserEnv','client_info');
      l_author  varchar2(100) := lower(sys_context('jm_ctx','author'));
      l_recips  varchar2(1000):='';  
      l_res     number;
    begin
      select count(1) into l_res from user_tables where table_name = 'NOT_SENDED_FTP';
      ------------------------------------------------------------
      if l_res =0 then 
        execute immediate 'create table not_sended_FTP
                         (job_id      number,
                          client_info varchar2(100),
                          author      varchar2(100),
                          Recipients  varchar2(500),
                          attach_num  number,
                          attach_name varchar2(100),  
                          attach_clob clob,
                          navi_date   date          default sysdate,
                          sid         number        default sys_context(''userenv'',''sid''),
                          error_msg   varchar2(1000),
                          iid         number,
                          processed   number
                         )
                         pctfree 0 ';
         execute immediate '                         
            CREATE OR REPLACE TRIGGER not_sended_FTP_rid
             BEFORE
              INSERT
             ON not_sended_FTP
            REFERENCING NEW AS NEW OLD AS OLD
             FOR EACH ROW
            begin
              select idanytable_seq.nextval into :new.iid from dual;
            end;';
                                 
        execute immediate 'comment on table not_sended_FTP is ''Вложения не отправленные объектом TFTPRECORD по причине err_msg''';
      end if;

      ------------------------------------------------------------
      if p_recip is null then 
          if recipList is not null and recipList.count>0 then 
            for i in recipList.first .. recipList.last
            loop
              l_recips := l_recips ||','||recipList(i);
            end loop;
            l_recips := substr(l_recips,2);
          end if;
      else 
        l_recips := p_recip;
      end if;

      ------------------------------------------------------------
      execute immediate 'insert into not_sended_FTP(job_id, client_info, author,
                                Recipients, attach_num, attach_name, attach_clob, error_msg) 
                         values (:job_id, :client_info, :author,
                                :Recipients, :anum, :aname, :aclob, :error_msg)'
                         using l_job_id, l_info, l_author,l_recips, l_res, p_fname, p_file, p_err;
                l_res := l_res + 1;
      commit;
            
    end; -- конец вложенной функции SaveToTab
    
    
------------------------------------------------------------- 
  begin
    if recipList is not null and recipList.count>0 then 
        if (filenames is null) or (filenames.count=0) then return -1; end if;
        if (files is null) or (files.count=0) then return -2; end if;
        if filenames.count <> files.count then return -3; end if;
        -- по всем адресатам
        for j in recipList.first .. recipList.last
        loop
          begin
              l_conn := ftp.login( recipList(j) );
              l_syst := ftp.getsystem(l_conn);
              if length(fpath)>0 then 
                  if lower(l_syst) not like '%windows%' then 
                    fpath := replace(fpath,'/','\')||'\';
                  else
                    fpath := fpath||'/';
                  end if;
              end if;
              for i in filenames.first .. filenames.last
              loop
                  begin
                    if IsArch = 1 then 
                      l_b := pck_zip.clob_compress(files(i), filenames(i));
                      ftp.put_remote_binary_data(l_conn, nvl(fpath,'')||substr(filenames(i),1,instr(filenames(i),'.'))||'zip', l_b);    
                    else
                      ftp.put_remote_ascii_data(l_conn, nvl(fpath,'')||filenames(i), files(i));    
                    end if;
                  exception
                    when others then
                      l_errmsg  := dbms_utility.format_error_stack()||chr(13)||chr(10)||dbms_utility.format_error_backtrace();
                      SaveToTab(recipList(j), filenames(i), files(i), l_errmsg);
                  end;
              end loop; -- по всем адресатам одного файла
              ftp.logout(l_conn);
          exception -- при логине в систему и определении ее параметров, произошла ошибка
            when others then 
              l_errmsg  := dbms_utility.format_error_stack()||chr(13)||chr(10)||dbms_utility.format_error_backtrace();
              for i in filenames.first .. filenames.last
              loop
                SaveToTab(recipList(j), filenames(i), files(i), l_errmsg);
              end loop;
          end;
        end loop;
    else
       for i in filenames.first .. filenames.last
       loop
         SaveToTab(null, filenames(i), files(i), 'нет списка получателей');
       end loop;
       l_sendres := -10;
    end if;
    
    return l_sendres;
  end; 

  ------------------------------------------------------------------------
end;
/
-- End of DDL Script for Type Body TRANSFORMER.TFTPRECORD

-- Start of DDL Script for Type Body TRANSFORMER.TJOB
-- Generated 14/10/2014 11:04:43 from TRANSFORMER@DWHKVK

CREATE OR REPLACE 
TYPE tjob
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

-- Grants for Type
GRANT EXECUTE ON tjob TO sparshukov
/
GRANT EXECUTE ON tjob TO ldwh
/

CREATE OR REPLACE 
TYPE BODY tjob
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


-- End of DDL Script for Type Body TRANSFORMER.TJOB

-- Start of DDL Script for Type Body TRANSFORMER.TMAIL
-- Generated 14/10/2014 11:04:43 from TRANSFORMER@DWHKVK
CREATE OR REPLACE 
TYPE tmail
as object
(
  MailSubj        varchar2(255),
  MailBody        clob,
  Recipients      TStringList,
  attach_names    TStringList,
  attach_files    TClobList,
  IsArch          number,
  ArchPass        varchar2(50),
  member procedure SetRecipients(p_recip in varchar2) ,
  member procedure SetRecipients(p_recip in TStringList default null) ,
  member function  SendReport return number,
  static function MailCreate( p_MailSubj        varchar2,
                              p_MailBody        clob,
                              p_attach_names    TStringList,
                              p_attach_files    TClobList
                              ) return TMail
)
/

-- Grants for Type
GRANT EXECUTE ON tmail TO rkrikunov
/
GRANT EXECUTE ON tmail TO skhizhnjak
/
GRANT EXECUTE ON tmail TO sparshukov
/
GRANT EXECUTE ON tmail TO ldwh
/

CREATE OR REPLACE 
TYPE BODY tmail
is
  ------------------------------------------------------------------------
  -- author = sparshukov
  ------------------------------------------------------------------------
  -- конструктор - все элементы объекта нужно инициализировать для простоты работы с ними в дальнейшем
  static function MailCreate( p_MailSubj        varchar2,
                              p_MailBody        clob,
                              p_attach_names    TStringList,
                              p_attach_files    TClobList
                              ) return TMail
  is
  begin
    return TMAIL(p_MailSubj,    -- p_MailSubj
                 p_MailBody,    -- MailBody 
                 TStringList(),
                 p_attach_names,-- r_mail
                 p_attach_files,-- TFtpRecord 
                 0,             -- p_IsArch
                 ''           -- p_ArchPass
                 );
  end MailCreate;
  
  ------------------------------------------------------------------------
  member procedure SetRecipients(p_recip in varchar2)
  is 
  begin
    SetRecipients(TStringList(p_recip));
  end;

  ------------------------------------------------------------------------
  member procedure SetRecipients(p_recip in TStringList default null) 
  is
    ts   TStringList := TStringList();
    rs   number;
    usr  varchar2(100);
    eml  varchar2(100); 
  begin
    if p_recip is not null then 
      if p_recip.count=0 then 
         SetRecipients;
      end if;
      -- проверка переданного списка е-майлов на вшивость по маске
      for i in p_recip.first .. p_recip.last
      loop
          select count(1) into rs from (select p_recip(i) email from dual) where email like '%_@_%._%';
          if rs=1 then 
            ts.extend;
            ts(ts.count) := p_recip(i);
          end if;
      end loop;
      Recipients := ts;
      
    else 
      usr := lower(sys_context('jm_ctx','author'));
      if usr not in ('sparshukov', 'rkrikunov', 'skhizhnjak', 'rvasin', 'vasin_rs', 'drastvorov', 'rastvorov_db') 
         or usr is null
      then 
        execute immediate 'select lower(case when user in (''DEPSTAT'',''TRANSFORMER'', ''LDWH'') then osuser else osuser end) usr from v$session where sid=sys_context(''userenv'',''sid'')' into usr;
      end if;
      eml := case when usr='sparshukov'   then 'sergey.parshukov@megafonkavkaz.ru'
                  when usr='rkrikunov'    then 'ruslan.krikunov@megafonkavkaz.ru'
                  when usr='skhizhnjak'   then 'sergejj.khizhnjak@megafonkavkaz.ru'
                  when usr='rvasin'       then 'roman.vasin@megafonkavkaz.ru'
                  when usr='vasin_rs'     then 'roman.vasin@megafonkavkaz.ru'
                  when usr='drastvorov'   then 'dmitry.rastvorov@megafonkavkaz.ru'
                  when usr='rastvorov_db' then 'dmitry.rastvorov@megafonkavkaz.ru'
             end; 
      Recipients := TStringList( eml );
    end if;
  end;
  
  ------------------------------------------------------------------------
  member function SendReport return number
  is
    l_sendres number        := 0;
    l_job_id  number        := sys_context('jm_ctx','job_id');
    l_info    varchar2(100) := sys_context('UserEnv','client_info');
    l_author  varchar2(100) := lower(sys_context('jm_ctx','author'));
    l_res     number;
    l_recips  varchar2(1000):='';  
    l_errmsg  varchar2(1000):='';    
    p_clb     TClobList     := null;   
  begin
    if Recipients is not null and Recipients.count>0 then 
      begin
         if (attach_names is not null and attach_names.count>=1) and 
            (attach_files is not null and attach_files.count>=1) then 
          l_sendres := emailsender.sendemailwithattach(              
                  Recipients,
                  mailSubj,
             	  mailBody,
      			  attach_names, 
                  attach_files,
                  case when IsArch=1 then true else false end, 
                  ArchPass
                  );
        else
          l_sendres := emailsender.sendemailwithattach(              
                  Recipients,
                  mailSubj,
             	  mailBody,
      			  null,     
                  p_clb     );
        end if;
      exception
        when others then
          l_sendres := sqlcode;
          l_errmsg  := dbms_utility.format_error_stack()||chr(13)||chr(10)||dbms_utility.format_error_backtrace();
      end;
    else
      l_sendres := -10;
      l_errmsg  := 'нет списка получателей';
    end if;

    ------------------------------------------------------------
    -- если отправка по почте не удалась
    if l_sendres < 0 then 
      select count(1) into l_res from user_tables where table_name = 'NOT_SENDED_EMAIL';
      ------------------------------------------------------------
      if l_res =0 then 
        execute immediate 'create table not_sended_email
                         (job_id      number,
                          client_info varchar2(100),
                          author      varchar2(100),
                          Recipients  varchar2(500),
                          mail_Subj   varchar2(500),  
                          mail_body   clob,
                          attach_num  number,
                          attach_name varchar2(100),  
                          attach_clob clob,
                          navi_date   date          default sysdate,
                          sid         number        default sys_context(''userenv'',''sid''),
                          error_msg   varchar2(1000)  
                         )
                         pctfree 0 ';
        execute immediate 'comment on table not_sended_EMAIL is ''Вложения не отправленные объектом TMAIL по причине err_msg''';
      end if;
      
      ------------------------------------------------------------
      if Recipients is not null and Recipients.count>0 then 
        for i in Recipients.first .. Recipients.last
        loop
          l_recips := l_recips ||','||Recipients(i);
        end loop;
        l_recips := substr(l_recips,2);
      end if;
      
      ------------------------------------------------------------
      if attach_files.count=0 then 
        execute immediate 'insert into not_sended_EMAIL(job_id, client_info, author,
                                        Recipients, mail_Subj, mail_body, attach_num, error_msg) 
                           values (:job_id, :client_info, :author,
                                        :Recipients, :mail_Subj, :mail_body, 0, :error_msg)'
                   using l_job_id, l_info, l_author,l_recips, mailSubj, MailBody, l_errmsg;
      else
           l_res := 1;
          for i in attach_files.first .. attach_files.last
          loop
                execute immediate 'insert into not_sended_EMAIL(job_id, client_info, author,
                                                Recipients, mail_Subj, mail_body, attach_num, 
                                                attach_name, attach_clob, error_msg) 
                                   values (:job_id, :client_info, :author,
                                                :Recipients, :mail_Subj, :mail_body, :anum, 
                                                :aname, :aclob, :error_msg)'
                           using l_job_id, l_info, l_author,l_recips, mailSubj, MailBody, l_res, 
                                 attach_names(i), attach_files(i), l_errmsg;
                l_res := l_res + 1;
          end loop;
      end if;
      commit;
    end if; -- если отправка по почте не удалась
    
    return l_sendres;
  exception 
    when others then 
       dbms_output.put_line('sr: '||dbms_utility.format_error_stack()||chr(13)||chr(10)||dbms_utility.format_error_backtrace());  
       return sqlcode;
  end;
  
end;
/


-- End of DDL Script for Type Body TRANSFORMER.TMAIL

-- Start of DDL Script for Type Body TRANSFORMER.TREPORT
-- Generated 14/10/2014 11:04:43 from TRANSFORMER@DWHKVK
CREATE OR REPLACE 
TYPE treport 
as object
( 
  result          number,
  result_txt      varchar2(500),
  viaSystem       number,       -- 0=неопределена, 1=Email, 2=FTP
  r_mail          TMail,
  r_ftp           TFtpRecord,
  reportStart     date ,
  reportSend      date , 
  -- для сортировок
  MAP MEMBER FUNCTION get_result RETURN NUMBER,
  -- конструктор
  static function ReportCreate(p_res in number, p_res_txt in varchar2) return TReport,
  -- установка списка получателей
  member procedure SetRecipients (p_recip in TStringList) ,
  -- отправка отчета через отчетную систему
  member function SendReport(p_reportSend in out date) return number
)
/

-- Grants for Type
GRANT EXECUTE ON treport TO sparshukov
/
GRANT EXECUTE ON treport TO ldwh
/

CREATE OR REPLACE 
TYPE BODY treport
as
  -- для сортировок
  map member function get_result return number
  is
  begin
    return result;
  end get_result;

  -- конструктор
  static function ReportCreate(p_res in number, p_res_txt in varchar2) return TReport
  is
  begin
    return TReport(p_res, p_res_txt, 
                  0,
                  null,    -- r_mail
                  null    -- TFtpRecord 
                  /*null,null,null -- params */
                  ,null    -- reportStart
                  ,sysdate -- reportSend
                  );
  end ReportCreate;

  -- установка списка получателей  
  member procedure SetRecipients(p_recip in TStringList) 
  is 
    l_prefix varchar2(4);
  begin
    if p_recip is not null then
      if p_recip.count > 0 then 
        l_prefix := upper(substr(p_recip(1), 1, 4));
        viaSystem := case when l_prefix='FTP:' then 2 else 1 end;
        if (viaSystem = 1) and (r_mail is not null) then 
          r_mail.SetRecipients(p_recip);
        elsif (viaSystem = 2) and (r_ftp is not null) then 
          -- 'FTP://dealer_upload:bKB8pTPc@10.23.10.234'
          r_ftp.SetRecipients(p_recip);
        end if;
      else
        raise_application_Error(-20001,'Список получателей пуст');
      end if;
    else
      raise_application_Error(-20001,'Передан пустой указатель на список получателей');
    end if;
  end;

  -- отправка отчета через отчетную систему
  member function SendReport(p_reportSend in out date) return number
  is
  begin
--    if viaSystem = 1 then 
      if r_mail is not null then
        p_reportSend := sysdate;
        return r_mail.sendReport;
      --else
      --  raise_application_Error(-20001,'TReport.viaSystem=1, но r_mail is null');
      end if;
  --  elsif (viaSystem = 2) then
      if r_ftp is not null then
        p_reportSend := sysdate;
        return r_ftp.sendReport;
      --else
      --  raise_application_Error(-20002,'TReport.viaSystem=2, но r_ftp is null');
      end if;
--    else
--      raise_application_Error(-20003, 'TReport.viaSystem not in (1,2) т.е. неопределена='||nvl(to_char(viaSystem),'null'));
--    end if;
  end SendReport;
  
end;-- End of DDL Script for Type DEPSTAT.TREPORT
/


-- End of DDL Script for Type Body TRANSFORMER.TREPORT

-- Start of DDL Script for Type Body TRANSFORMER.TRITEM
-- Generated 14/10/2014 11:04:44 from TRANSFORMER@DWHKVK
CREATE OR REPLACE 
TYPE tritem as object
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

-- Grants for Type
GRANT EXECUTE ON tritem TO ldwh
/

CREATE OR REPLACE 
TYPE BODY tritem
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
          lb := pck_zip.clob_compress(dc, itemName||'.'||itemext);
          self.archPass := l_pass;
        else  
          lb := pck_zip.clob_compress(dc, itemName||'.'||itemext);
        end if;
      end if;
      if bitand(DataType,2)>0 then 
        if length(archPass)>0 then
          lb := pck_zip.clob_compress(dc, itemName||'.'||itemext);
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


-- End of DDL Script for Type Body TRANSFORMER.TRITEM

