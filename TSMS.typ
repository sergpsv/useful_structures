CREATE OR REPLACE TYPE "TSMS"
as object 
(
  recip         varchar2(15),   -- один получатель
  recipients    TStringList,    -- список получателей
  sender        varchar2(20),   -- кем подписываться
  message       varchar2(1000), -- тело сообщения
  delayed       date,           -- если доставка отложена, то здесь конкретная дата отправки
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
when usr='SPARSHUKOV'         then '79282011384'
when usr='SERGEY.PARSHUKOV'   then '79282011384'                            
when usr='RKRIKUNOV'          then '79289072396'
when usr='RUSLAN.KRIKUNOV'    then '79289072396'                      
when usr='SKHIZHNJAK'         then '79282011384'                      
when usr='VIVAKIN'            then '79381112264'
when usr='VLADIMIR.IVAKIN'    then '79381112264'
when usr='ALEXANDER.TARANENKO'then '79282019951'
--when usr='SERGEY.TARASENKO'   then '79282012680'
--when usr='TARASENKO_SS'       then '79282012680'
when usr='LEVENETS_EE'        then '79282015240'
when usr='ANTIBIOTIC'         then '79282015240'
                              else '79282011384' end; 
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
  -- конструктор
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
