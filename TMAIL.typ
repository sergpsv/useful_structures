CREATE OR REPLACE TYPE "TMAIL"
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
CREATE OR REPLACE TYPE BODY "TMAIL"
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
      if usr not in ('sparshukov', 'rkrikunov', 'vivakin', 'levenets_ee', 'taranenko_aa') 
         or usr is null
      then 
        execute immediate 'select lower(case when user in (''DEPSTAT'',''TRANSFORMER'', ''LDWH'') then osuser else osuser end) usr from v$session where sid=sys_context(''userenv'',''sid'')' into usr;
      end if;
      eml := case when usr='sparshukov'   then 'sergey.parshukov@megafon.ru'
                  when usr='rkrikunov'    then 'ruslan.krikunov@megafon.ru'
                  when usr='vivakin'      then 'vladimir.ivakin@MegaFon.ru'
                  when usr='levenets_ee'  then 'Evgeny.Levenets@MegaFon.ru'
                  when usr='taranenko_aa' then 'Alexander.Taranenko@MegaFon.ru'
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
          l_sendres := emailsender.SendEmailWithAttach(              
                  Recipients,
                  mailSubj,
             	  mailBody,
     			  null, 
                  p_clb
                  );
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
