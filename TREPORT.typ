CREATE OR REPLACE TYPE "TREPORT"
as object
( 
  result          number,
  result_txt      varchar2(500),
  viaSystem       number,       -- 0=������������, 1=Email, 2=FTP
  r_mail          TMail,
  r_ftp           TFtpRecord,
  reportStart     date ,
  reportSend      date , 
  -- ��� ����������
  MAP MEMBER FUNCTION get_result RETURN NUMBER,
  -- �����������
  static function ReportCreate(p_res in number, p_res_txt in varchar2) return TReport,
  -- ��������� ������ �����������
  member procedure SetRecipients (p_recip in TStringList) ,
  -- �������� ������ ����� �������� �������
  member function SendReport(p_reportSend in out date) return number
)
/
CREATE OR REPLACE TYPE BODY "TREPORT"
as
  -- ��� ����������
  map member function get_result return number
  is
  begin
    return result;
  end get_result;

  -- �����������
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

  -- ��������� ������ �����������  
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
        raise_application_Error(-20001,'������ ����������� ����');
      end if;
    else
      raise_application_Error(-20001,'������� ������ ��������� �� ������ �����������');
    end if;
  end;

  -- �������� ������ ����� �������� �������
  member function SendReport(p_reportSend in out date) return number
  is
  begin
--    if viaSystem = 1 then 
      if r_mail is not null then
        p_reportSend := sysdate;
        return r_mail.sendReport;
      --else
      --  raise_application_Error(-20001,'TReport.viaSystem=1, �� r_mail is null');
      end if;
  --  elsif (viaSystem = 2) then
      if r_ftp is not null then
        p_reportSend := sysdate;
        return r_ftp.sendReport;
      --else
      --  raise_application_Error(-20002,'TReport.viaSystem=2, �� r_ftp is null');
      end if;
--    else
--      raise_application_Error(-20003, 'TReport.viaSystem not in (1,2) �.�. ������������='||nvl(to_char(viaSystem),'null'));
--    end if;
  end SendReport;
  
end;-- End of DDL Script for Type DEPSTAT.TREPORT
/
