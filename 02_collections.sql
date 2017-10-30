CREATE OR REPLACE 
type tstringlist as table of varchar2(255)
/
CREATE OR REPLACE 
type tbloblist as table of blob
/
CREATE OR REPLACE 
type tcloblist as table of clob
/
CREATE OR REPLACE 
type tritemlist as table of TRItem --index by number
/


GRANT EXECUTE ON tcloblist TO sparshukov
/
GRANT EXECUTE ON tritemlist TO sparshukov
/
GRANT EXECUTE ON tstringlist TO sparshukov
/
GRANT EXECUTE ON tritemlist TO sparshukov
/


-- End of DDL Script for Type TRANSFORMER.TSTRINGLIST

