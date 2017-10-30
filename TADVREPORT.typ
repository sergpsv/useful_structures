CREATE OR REPLACE TYPE "TADVREPORT"                                          as object
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
    member function SaveToTab(self in out tadvReport, p_chanel in varchar2, p_recipList TStringList, p_err varchar2) return number,
 
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
CREATE OR REPLACE TYPE BODY "TADVREPORT"
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
    when l_what = 'defaultftp' then 'ftp://statupl:b8thbYifmqzDg4Gn3iup@10.61.10.130'
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
          l_debug('('||l_list(i)||')');
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
    member function SaveToTab(self in out tadvReport, p_chanel in varchar2, p_recipList TStringList, p_err varchar2) return number
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
      l_debug('Сохранил в not_sended_Report');
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
          l_debug(l_errmsg);
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
                        where job_id = :p and nvl(enabled,0)=1 and nvl(MAXSENDDATE,to_date(''31/12/2999'',''dd/mm/yyyy''))>sysdate' using self.job_id;
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
      j_manager.ctx_set('footer2','Коллеги! в связи с закрытие локальных хранилищ данных с 31/07/2016 рассылка данного отчета будет прекращена');
      j_manager.ctx_set('footer3','Прошу использовать КХД (http://sapbo:8080/BOE/BI). Доступ - через МегаХелп.');
      j_manager.ctx_set('footer4','портал: https://branches.meganet.megafon.ru/reporting/default.aspx');
      j_manager.ctx_set('footer5','Описания юниверсов:  https://branches.meganet.megafon.ru/reporting/Lists/universes/AllItems.aspx');
      j_manager.ctx_set('footer6','Описания отчетов:  https://megawiki.megafon.ru/x/BAM-Ag');
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
