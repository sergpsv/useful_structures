CREATE OR REPLACE TYPE "TSMS"
as object 
(
  recip         varchar2(15),   -- îäèí ïîëó÷àòåëü
  recipients    TStringList,    -- ñïèñîê ïîëó÷àòåëåé
  sender        varchar2(20),   -- êåì ïîäïèñûâàòüñÿ
  message       varchar2(1000), -- òåëî ñîîáùåíèÿ
  delayed       date,           -- åñëè äîñòàâêà îòëîæåíà, òî çäåñü êîíêðåòíàÿ äàòà îòïðàâêè
  member procedure SetRecipient(p_recipient varchar2),
  member procedure SetRecipient(p_recipientList TStringList default null),
  member procedure SendSmsWoCommit(p_delayed date default null),
  member procedure SendSms(p_delayed date default null),
  static function smsCreate(p_message   varchar2, p_recipient varchar2 default null) return TSms
)
/
CREATE OR REPLACE TYPE BODY "TSMS"
as

  ------------------------------------------------------------------
  member procedure SetRecipient(p_recipient in varchar2) 
  is
  begin
    SetRecipient(TstringList(p_recipient));
  end;

  ------------------------------------------------------------------
  member procedure SetRecipient(p_recipientList in TStringList default null) 
  is
    usr    varchar2(50);
    msd    varchar2(15); 
  begin
    if p_recipientList is not null then 
      if p_recipientList.count=0 then 
         SetRecipient;
      end if;
      Recipients := p_recipientList;
    else 
      usr := upper(sys_context('jm_ctx','author'));
      if usr is null then 
         execute immediate 'select upper(case when user in (''DEPSTAT'',''TRANSFORMER'', ''LDWH'', ''UNISTAT'') then osuser else osuser end) usr from v$session where sid=sys_context(''userenv'',''sid'')' 
         into usr;
         self.message := self.message || '(osuser='||usr||')';
      end if;
      msd := case 
when usr='SPARSHUKOV'         then '7928000000'
when usr='SERGEY.PARSHUKOV'   then '7928000000'                            
when usr='RKRIKUNOV'          then '7928000000'
when usr='RUSLAN.KRIKUNOV'    then '7928000000'                      
when usr='SKHIZHNJAK'         then '7928000000'                      
when usr='VIVAKIN'            then '7928000000'
when usr='VLADIMIR.IVAKIN'    then '7928000000'
when usr='ALEXANDER.TARANENKO'then '7928000000'
--when usr='SERGEY.TARASENKO'   then '7928000000'
--when usr='TARASENKO_SS'       then '7928000000'
when usr='LEVENETS_EE'        then '7928000000'
when usr='ANTIBIOTIC'         then '7928000000'
                              else '7928000000' end; 
      Recipients := TStringList( msd );
    end if;
  end;

  ------------------------------------------------------------------
  member procedure SendSmsWoCommit(p_delayed date default null)
  is
    jobid number;
  begin
    if recipients is null or recipients.count=0 then 
       setRecipient;
    end if;
    
    if recipients is null or recipients.count=0 or message is null then 
       return;
    end if;
   
    if delayed is null and lower(sys_context('userEnv','server_host'))='buddha' then 
      for i in recipients.first .. recipients.last 
      loop
        execute immediate 'insert into bis.mk$alarm_list values (0, '''||recipients(i)||''', substr('''||message||''',1,990))';
      end loop;
    else
      for i in recipients.first .. recipients.last
      loop
        dbms_job.submit(jobid,'begin insert into bis.mk$alarm_list@tobis_dp values (0, '''||recipients(i)||''', substr('''||message||''',1,990)); commit; end;');
      end loop;
    end if;
  end;

  ------------------------------------------------------------------
  member procedure SendSms(p_delayed date default null)
  is
    jobid number;
  begin
    SendSmsWoCommit(p_delayed);
    commit;
  end;

  ------------------------------------------------------------------
  -- êîíñòðóêòîð
  static function smsCreate( p_message   varchar2, p_recipient varchar2 default null
                           ) return TSms
  is
  begin
    return TSms (p_recipient,    -- p_MailSubj
                 case when p_recipient is not null then TStringList(p_recipient) else TStringList() end,    -- MailBody 
                 null,      -- sender
                 p_message, -- message
                 null       -- delayed
                 );
  end smsCreate;
  
  ------------------------------------------------------------------
end;
/
