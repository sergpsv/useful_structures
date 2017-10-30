CREATE OR REPLACE TYPE "STRAGG_TYPE_CTX"                                          as object
(
  string varchar2 (4000),

  static function ODCIAggregateInitialize
    ( sctx in out stragg_type_ctx )
    return number ,

  member function ODCIAggregateIterate
    ( self  in out stragg_type_ctx ,
      value in     varchar2
    ) return number ,

  member function ODCIAggregateTerminate
    ( self        in  stragg_type_ctx,
      returnvalue out varchar2,
      flags in number
    ) return number ,

  member function ODCIAggregateMerge
    ( self in out stragg_type_ctx,
      ctx2 in     stragg_type_ctx
    ) return number
);
/
CREATE OR REPLACE TYPE BODY "STRAGG_TYPE_CTX"
is

  static function ODCIAggregateInitialize
  ( sctx in out stragg_type_ctx )
  return number
  is
  begin

    sctx := stragg_type_ctx( null ) ;

    return ODCIConst.Success ;

  end;

  member function ODCIAggregateIterate
  ( self  in out stragg_type_ctx ,
    value in     varchar2
  ) return number
  is
  begin

    self.string := self.string || nvl(sys_context('jm_ctx','str_agg_delimiter'),',') || value ;

    return ODCIConst.Success;

  end;

  member function ODCIAggregateTerminate
  ( self        in  stragg_type_ctx ,
    returnvalue out varchar2 ,
    flags       in  number
  ) return number
  is
  begin

    returnValue := ltrim( self.string, nvl(sys_context('jm_ctx','str_agg_delimiter'),',') );

    return ODCIConst.Success;

  end;

  member function ODCIAggregateMerge
  ( self in out stragg_type_ctx ,
    ctx2 in     stragg_type_ctx
  ) return number
  is
  begin

    self.string := self.string || ctx2.string;

    return ODCIConst.Success;

  end;

end;
/
