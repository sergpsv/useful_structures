CREATE OR REPLACE TYPE "TFTPRECORD"
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
CREATE OR REPLACE TYPE BODY "TFTPRECORD"
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
