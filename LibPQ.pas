unit LibPQ;
{

  LibPQ: libpq.dll wrapper

  https://github.com/stijnsanders/DataLank

  based on PostgreSQL 9.5
  include/libpq-fe.h

}

interface

//debugging: prevent step-into from debugging TQueryResult calls:
{$D-}
{$L-}

type
  Oid = cardinal; //Postgres Object ID
  POid = ^Oid;

const
  InvalidOid {:Oid} = 0;
  OID_MAX = cardinal(-1);//UINT_MAX;

  PG_DIAG_SEVERITY		       = 'S';
  PG_DIAG_SQLSTATE		       = 'C';
  PG_DIAG_MESSAGE_PRIMARY    = 'M';
  PG_DIAG_MESSAGE_DETAIL	   = 'D';
  PG_DIAG_MESSAGE_HINT	     = 'H';
  PG_DIAG_STATEMENT_POSITION = 'P';
  PG_DIAG_INTERNAL_POSITION  = 'p';
  PG_DIAG_INTERNAL_QUERY	   = 'q';
  PG_DIAG_CONTEXT			       = 'W';
  PG_DIAG_SCHEMA_NAME		     = 's';
  PG_DIAG_TABLE_NAME		     = 't';
  PG_DIAG_COLUMN_NAME		     = 'c';
  PG_DIAG_DATATYPE_NAME	     = 'd';
  PG_DIAG_CONSTRAINT_NAME    = 'n';
  PG_DIAG_SOURCE_FILE		     = 'F';
  PG_DIAG_SOURCE_LINE		     = 'L';
  PG_DIAG_SOURCE_FUNCTION    = 'R';

  PG_COPYRES_ATTRS		    = $1;
  PG_COPYRES_TUPLES		    = $2;	// Implies PG_COPYRES_ATTRS
  PG_COPYRES_EVENTS		    = $4;
  PG_COPYRES_NOTICEHOOKS  = $8;

type
  ConnStatusType = (
	  CONNECTION_OK,
	  CONNECTION_BAD,
 	  CONNECTION_STARTED,
 	  CONNECTION_MADE,
 	  CONNECTION_AWAITING_RESPONSE,
 	  CONNECTION_AUTH_OK,
 	  CONNECTION_SETENV,
 	  CONNECTION_SSL_STARTUP,
 	  CONNECTION_NEEDED
  );

  PostgresPollingStatusType = (
	  PGRES_POLLING_FAILED,
 	  PGRES_POLLING_READING,
 	  PGRES_POLLING_WRITING,
 	  PGRES_POLLING_OK,
 	  PGRES_POLLING_ACTIVE
  );

  ExecStatusType = (
    PGRES_EMPTY_QUERY,
    PGRES_COMMAND_OK,
    PGRES_TUPLES_OK,
    PGRES_COPY_OUT,
    PGRES_COPY_IN,
    PGRES_BAD_RESPONSE,
    PGRES_NONFATAL_ERROR,
    PGRES_FATAL_ERROR,
    PGRES_COPY_BOTH,
    PGRES_SINGLE_TUPLE
  );

  PGTransactionStatusType = (
    PQTRANS_IDLE,
    PQTRANS_ACTIVE,
    PQTRANS_INTRANS,
    PQTRANS_INERROR,
    PQTRANS_UNKNOWN
  );

  PGVerbosity = (
    PQERRORS_TERSE,
    PQERRORS_DEFAULT,
    PQERRORS_VERBOSE
  );

  PGPing = (
    PQPING_OK,
    PQPING_REJECT,
    PQPING_NO_RESPONSE,
    PQPING_NO_ATTEMPT
  );

type
  PGConn = record
    Handle:pointer;//opaque
  end;

  PGResult = record
    Handle:pointer;//opaque
  end;

  PGCancel = record
    Handle:pointer;//opaque
  end;

  PpgNotify = ^pgNotify;

  PGnotify = record
    relname: PAnsiChar;
    pe_pid: integer;
    extra: PAnsiChar;
    next: PpgNotify;
  end;

  PQnoticeReceiver = procedure(arg:pointer;res:PGResult); cdecl;
  PQnoticeProcessor = procedure(arg:pointer;msg:PAnsiChar); cdecl;

  pgbool = byte;

  _PQprintOpt = packed record
     header, align, standard, html3, pager: pgbool;
     fieldSep, tableOpt, caption: PAnsiChar;
     fieldName: PPAnsiChar; //PAnsiChar? delimited by #0#0?
  end;
  PQprintOpt = ^_PQprintOpt;

  _PQconninfoOption = record
    keyword, envvar, compiled, val, label_, dispchar: PAnsiChar;
    dispsize: integer;
  end;
  PQconninfoOption = ^_PQconninfoOption;

  _PQArgBlock = record
    len, isint: integer;
    case integer of
      0: (ptr: PInteger);
      1: (integer_: integer);
  end;
  PQArgBlock = ^_PQArgBlock;

  _PGresAttDesc = record
    name: PAnsiChar;
    tableid: Oid;
    columnid: integer;
	  format: integer;
	  typid: Oid;
    typlen: integer;
    atttypmod: integer;
  end;
  PGresAttDesc = ^_PGresAttDesc;


function PQconnectStart(conninfo: PAnsiChar): PGconn; cdecl;
function PQconnectStartParams(keywords, values: PPAnsiChar; expand_dbname: integer): PGconn; cdecl;
function PQconnectPoll(conn: PGconn): PostgresPollingStatusType; cdecl;

function PQconnectdb(conninfo: PAnsiChar): PGconn; cdecl;
function PQconnectdbParams(keywords, values: PPAnsiChar; expand_dbname: integer): PGconn; cdecl;
function PQsetdbLogin(pghost, pgport, pgoptions, pgtty, dbName, login, pwd: PAnsiChar): PGconn; cdecl;

//#define
//  PQsetdb(M_PGHOST,M_PGPORT,M_PGOPT,M_PGTTY,M_DBNAME)
//	PQsetdbLogin(M_PGHOST, M_PGPORT, M_PGOPT, M_PGTTY, M_DBNAME, NULL, NULL)

procedure PQfinish(conn: PGconn); cdecl;
function PQconndefaults: PQconninfoOption; cdecl;
function PQconninfoParse(conninfo: PAnsiChar; var errmsg: PAnsiChar): PQconninfoOption; cdecl;
function PQconninfo(conn: PGconn): PQconninfoOption; cdecl;
procedure PQconninfoFree(connOptions: PQconninfoOption); cdecl;

function PQresetStart(conn: PGconn): integer; cdecl;
function PQresetPoll(conn: PGconn): PostgresPollingStatusType; cdecl;
procedure PQreset(conn: PGconn); cdecl;
function PQgetCancel(conn: PGconn): PGcancel; cdecl;
procedure PQfreeCancel(cancel: PGcancel); cdecl;
function PQcancel(cancel: PGcancel; errbuf: PAnsiChar; errbufsize: integer): integer; cdecl;
function PQrequestCancel(conn: PGconn): integer; cdecl;//deprecated

function PQdb(conn: PGconn): PAnsichar; cdecl;
function PQuser(conn: PGconn): PAnsichar; cdecl;
function PQpass(conn: PGconn): PAnsichar; cdecl;
function PQhost(conn: PGconn): PAnsichar; cdecl;
function PQport(conn: PGconn): PAnsichar; cdecl;
function PQtty(conn: PGconn): PAnsichar; cdecl;
function PQoptions(conn: PGconn): PAnsichar; cdecl;
function PQstatus(conn: PGconn): ConnStatusType; cdecl;
function PQtransactionStatus(conn: PGconn): PGTransactionStatusType; cdecl;
function PQparameterStatus(conn: PGconn; paramName: PAnsiChar): PAnsiChar; cdecl;
function PQprotocolVersion(conn: PGconn): integer; cdecl;
function PQserverVersion(conn: PGconn): integer; cdecl;
function PQerrorMessage(conn: PGconn): PAnsiChar; cdecl;
function PQsocket(conn: PGconn): integer; cdecl;
function PQbackendPID(conn: PGconn): integer; cdecl;
function PQconnectionNeedsPassword(conn: PGconn): integer; cdecl;
function PQconnectionUsedPassword(conn: PGconn): integer; cdecl;
function PQclientEncoding(conn: PGconn): integer; cdecl;
function PQsetClientEncoding(conn: PGconn; encoding: PAnsiChar): integer; cdecl;

function PQsslInUse(conn: PGconn): integer; cdecl;
function PQsslStruct(conn: PGconn; struct_name: PAnsiChar): pointer; cdecl;
function PQsslAttribute(conn: PGconn; attribute_name: PAnsiChar): PAnsiChar; cdecl;
function PQsslAttributeNames(conn: PGconn): PPAnsiChar; cdecl;

function PQgetssl(conn: PGconn): pointer; cdecl;

procedure PQinitSSL(do_init: integer);
procedure PQinitOpenSSL(do_ssl, do_crypto: integer);

function PQsetErrorVerbosity(conn: PGconn; verbosity: PGVerbosity): PGVerbosity; cdecl;

procedure PQtrace(conn: PGconn; debug_port: pointer {*FILE}); cdecl;
procedure PQuntrace(conn: PGconn); cdecl;

function PQsetNoticeReceiver(conn: PGconn; proc: PQnoticeReceiver; arg: pointer): PQnoticeReceiver; cdecl;
function PQsetNoticeProcessor(conn: PGconn; proc: PQnoticeProcessor; arg: pointer): PQnoticeProcessor; cdecl;

type pgthreadlock_t = type pointer; //typedef void (*pgthreadlock_t) (int acquire);

function PQregisterThreadLock(newhandler: pgthreadlock_t): pgthreadlock_t; cdecl;

//---
function PQexec(conn: PGconn; query: PAnsiChar): PGresult; cdecl;
function PQexecParams(conn: PGconn; command: PAnsiChar; nParams: integer;
			 paramTypes: POid; paramValues: PPAnsiChar; paramLengths: PInteger;
       paramFormats: PInteger; resultFormat: integer): PGresult; cdecl;
function PQprepare(conn: PGconn; stmtName: PAnsiChar;
		  query: PAnsiChar; nParams: integer; paramTypes: POid): PGresult; cdecl;
function PQexecPrepared(conn: PGconn; stmtName: PAnsiChar; nParams: integer;
			   paramValues: PPAnsiChar; paramLengths: PInteger;
         paramFormats: PInteger; resultFormat: integer): PGresult; cdecl;

function PQsendQuery(conn: PGconn; query: PAnsiChar): integer; cdecl;
function PQsendQueryParams(conn: PGconn; command: PAnsiChar; nParams: integer;
				  paramTypes: POid; paramValues: PPAnsiChar; paramLengths: PInteger;
				  paramFormats: PInteger; resultFormat: integer): integer; cdecl;
function PQsendPrepare(conn: PGconn; stmtName: PAnsiChar;
			  query: PAnsiChar; nParams: integer;
			  paramTypes: POid): integer; cdecl;
function PQsendQueryPrepared(conn: PGconn; stmtName: PAnsiChar; nParams: integer;
        paramValues: PPAnsiChar; paramLengths: PInteger;
        paramFormats: PInteger; resultFormat: integer): integer; cdecl;
function PQsetSingleRowMode(conn: PGconn): integer; cdecl;
function PQgetResult(conn: PGconn): PGresult; cdecl;

function PQisBusy(conn: PGconn): integer; cdecl;
function PQconsumeInput(conn: PGconn): integer; cdecl;

function PQnotifies(conn: PGconn): PGnotify; cdecl;

function PQputCopyData(conn: PGconn; buffer: PAnsiChar; nbytes: integer): integer; cdecl;
function PQputCopyEnd(conn: PGconn; errormsg: PAnsiChar): integer; cdecl;
function PQgetCopyData(conn: PGconn; buffer: PPAnsiChar; async: integer): integer; cdecl;

function PQsetnonblocking(conn: PGconn; arg: integer): integer; cdecl;
function PQisnonblocking(conn: PGconn): integer; cdecl;
function PQisthreadsafe: integer; cdecl;
function PQping(conninfo: PAnsiChar): PGPing; cdecl;
function PQpingParams(keywords: PPAnsiChar; values: PPAnsiChar; expand_dbname: integer): PGPing; cdecl;

function PQflush(conn: PGconn): integer; cdecl;

function PQfn(conn: PGconn; fnid: integer; result_buf: PInteger; result_len: PInteger; result_is_int: integer;
	 args: PQArgBlock; nargs: integer): PGresult; cdecl;

function PQresultStatus(res: PGResult): ExecStatusType; cdecl;
function PQresStatus(status: ExecStatusType): PAnsiChar; cdecl;
function PQresultErrorMessage(res: PGResult): PAnsiChar; cdecl;
function PQresultErrorField(res: PGResult; fieldcode: integer): PAnsiChar; cdecl;
function PQntuples(res: PGResult): integer; cdecl;
function PQnfields(res: PGResult): integer; cdecl;
function PQbinaryTuples(res: PGResult): integer; cdecl;
function PQfname(res: PGResult; field_num: integer): PAnsiChar; cdecl;
function PQfnumber(res: PGResult; field_name: PAnsiChar): integer; cdecl;
function PQftable(res: PGResult; field_num: integer): Oid; cdecl;
function PQftablecol(res: PGResult; field_num: integer): integer; cdecl;
function PQfformat(res: PGResult; field_num: integer): integer; cdecl;
function PQftype(res: PGResult; field_num: integer): Oid; cdecl;
function PQfsize(res: PGResult; field_num: integer): integer; cdecl;
function PQfmod(res: PGResult; field_num: integer): integer; cdecl;
function PQcmdStatus(res: PGresult): PAnsiChar; cdecl;
function PQoidValue(res: PGResult): Oid; cdecl;
function PQcmdTuples(res: PGresult): PAnsiChar; cdecl;
function PQgetvalue(res: PGResult; tup_num: integer; field_num: integer): PAnsiChar; cdecl;
function PQgetlength(res: PGResult; tup_num: integer; field_num: integer): integer; cdecl;
function PQgetisnull(res: PGResult; tup_num: integer; field_num: integer): integer; cdecl;
function PQnparams(res: PGResult): integer; cdecl;
function PQparamtype(res: PGResult; param_num: integer): Oid; cdecl;

function PQdescribePrepared(conn: PGconn; stmt: PAnsiChar): PGresult; cdecl;
function PQdescribePortal(conn: PGconn; portal: PAnsiChar): PGresult; cdecl;
function PQsendDescribePrepared(conn: PGconn; stmt: PAnsiChar): integer; cdecl;
function PQsendDescribePortal(conn: PGconn; portal: PAnsiChar): integer; cdecl;

procedure PQclear(res: PGResult); cdecl;

procedure PQfreemem(ptr: pointer); cdecl;

type
  size_t= cardinal;

function PQmakeEmptyPGresult(conn: PGconn; status: ExecStatusType): PGresult; cdecl;
function PQcopyResult(src: PGresult; flags: integer): PGresult; cdecl;
function PQsetResultAttrs(res: PGresult; numAttributes: integer; attDescs: PGresAttDesc): integer; cdecl;
function PQresultAlloc(res: PGresult; nBytes: size_t): pointer; cdecl;
function PQsetvalue(res: PGresult; tup_num: integer; field_num: integer; value: PAnsiChar; len: integer): integer; cdecl;

function PQescapeStringConn(conn: PGconn; to_: PAnsiChar; from: PAnsiChar; length: size_t; error: PInteger): size_t; cdecl;
function PQescapeLiteral(conn: PGconn; str: PAnsiChar; len: size_t): PAnsiChar; cdecl;
function PQescapeIdentifier(conn: PGconn; str: PAnsiChar; len: size_t): PAnsiChar; cdecl;
function PQescapeByteaConn(conn: PGconn; from: PByte; from_length: size_t; var to_length: size_t): PByte; cdecl;
function PQunescapeBytea(strtext: PByte; var retbuflen: size_t): PByte; cdecl;


procedure PQprint(fout: pointer{*FILE}; res: PGResult; ps: PQprintOpt); cdecl;

{
extern int	lo_open(conn: PGconn, Oid lobjId, int mode): integer; cdecl;
extern int	lo_close(conn: PGconn, int fd): integer; cdecl;
extern int	lo_read(conn: PGconn, int fd, char *buf, size_t len): integer; cdecl;
extern int	lo_write(conn: PGconn, int fd, const char *buf, size_t len): integer; cdecl;
extern int	lo_lseek(conn: PGconn, int fd, int offset, int whence): integer; cdecl;
extern pg_int64 lo_lseek64(conn: PGconn, int fd, pg_int64 offset, int whence): integer; cdecl;
extern Oid	lo_creat(conn: PGconn, int mode);
extern Oid	lo_create(conn: PGconn, Oid lobjId);
extern int	lo_tell(conn: PGconn, int fd): integer; cdecl;
extern pg_int64 lo_tell64(conn: PGconn, int fd);
extern int	lo_truncate(conn: PGconn, int fd, size_t len): integer; cdecl;
extern int	lo_truncate64(conn: PGconn, int fd, pg_int64 len): integer; cdecl;
extern int	lo_unlink(conn: PGconn, Oid lobjId): integer; cdecl;
extern Oid	lo_import(conn: PGconn, const char *filename);
extern Oid	lo_import_with_oid(conn: PGconn, const char *filename, Oid lobjId);
extern int	lo_export(conn: PGconn, Oid lobjId, const char *filename): integer; cdecl;
}

function PQlibVersion: integer; cdecl;

function PQmblen(s:PAnsiChar; encoding: integer): integer; cdecl;

function PQdsplen(s:PAnsiChar; encoding: integer): integer; cdecl;

function PQenv2encoding: integer; cdecl;

function PQencryptPassword(passwd: PAnsiChar; user: PAnsiChar): PAnsiChar; cdecl;

function pg_char_to_encoding(name: PAnsiChar): integer; cdecl;
function pg_encoding_to_char(encoding: integer): PAnsiChar; cdecl;
function pg_valid_server_encoding_id(encoding: integer): integer; cdecl;

implementation

function PQconnectStart; external 'libpq.dll';
function PQconnectStartParams; external 'libpq.dll';
function PQconnectPoll; external 'libpq.dll';
function PQconnectdb; external 'libpq.dll';
function PQconnectdbParams; external 'libpq.dll';
function PQsetdbLogin; external 'libpq.dll';
procedure PQfinish; external 'libpq.dll';
function PQconndefaults; external 'libpq.dll';
function PQconninfoParse; external 'libpq.dll';
function PQconninfo; external 'libpq.dll';
procedure PQconninfoFree; external 'libpq.dll';
function PQresetStart; external 'libpq.dll';
function PQresetPoll; external 'libpq.dll';
procedure PQreset; external 'libpq.dll';
function PQgetCancel; external 'libpq.dll';
procedure PQfreeCancel; external 'libpq.dll';
function PQcancel; external 'libpq.dll';
function PQrequestCancel; external 'libpq.dll';
function PQdb; external 'libpq.dll';
function PQuser; external 'libpq.dll';
function PQpass; external 'libpq.dll';
function PQhost; external 'libpq.dll';
function PQport; external 'libpq.dll';
function PQtty; external 'libpq.dll';
function PQoptions; external 'libpq.dll';
function PQstatus; external 'libpq.dll';
function PQtransactionStatus; external 'libpq.dll';
function PQparameterStatus; external 'libpq.dll';
function PQprotocolVersion; external 'libpq.dll';
function PQserverVersion; external 'libpq.dll';
function PQerrorMessage; external 'libpq.dll';
function PQsocket; external 'libpq.dll';
function PQbackendPID; external 'libpq.dll';
function PQconnectionNeedsPassword; external 'libpq.dll';
function PQconnectionUsedPassword; external 'libpq.dll';
function PQclientEncoding; external 'libpq.dll';
function PQsetClientEncoding; external 'libpq.dll';
function PQsslInUse; external 'libpq.dll';
function PQsslStruct; external 'libpq.dll';
function PQsslAttribute; external 'libpq.dll';
function PQsslAttributeNames; external 'libpq.dll';
function PQgetssl; external 'libpq.dll';
procedure PQinitSSL; external 'libpq.dll';
procedure PQinitOpenSSL; external 'libpq.dll';
function PQsetErrorVerbosity; external 'libpq.dll';
procedure PQtrace; external 'libpq.dll';
procedure PQuntrace; external 'libpq.dll';
function PQsetNoticeReceiver; external 'libpq.dll';
function PQsetNoticeProcessor; external 'libpq.dll';
function PQregisterThreadLock; external 'libpq.dll';
function PQexec; external 'libpq.dll';
function PQexecParams; external 'libpq.dll';
function PQprepare; external 'libpq.dll';
function PQexecPrepared; external 'libpq.dll';
function PQsendQuery; external 'libpq.dll';
function PQsendQueryParams; external 'libpq.dll';
function PQsendPrepare; external 'libpq.dll';
function PQsendQueryPrepared; external 'libpq.dll';
function PQsetSingleRowMode; external 'libpq.dll';
function PQgetResult; external 'libpq.dll';
function PQisBusy; external 'libpq.dll';
function PQconsumeInput; external 'libpq.dll';
function PQnotifies; external 'libpq.dll';
function PQputCopyData; external 'libpq.dll';
function PQputCopyEnd; external 'libpq.dll';
function PQgetCopyData; external 'libpq.dll';
function PQsetnonblocking; external 'libpq.dll';
function PQisnonblocking; external 'libpq.dll';
function PQisthreadsafe; external 'libpq.dll';
function PQping; external 'libpq.dll';
function PQpingParams; external 'libpq.dll';
function PQflush; external 'libpq.dll';
function PQfn; external 'libpq.dll';
function PQresultStatus; external 'libpq.dll';
function PQresStatus; external 'libpq.dll';
function PQresultErrorMessage; external 'libpq.dll';
function PQresultErrorField; external 'libpq.dll';
function PQntuples; external 'libpq.dll';
function PQnfields; external 'libpq.dll';
function PQbinaryTuples; external 'libpq.dll';
function PQfname; external 'libpq.dll';
function PQfnumber; external 'libpq.dll';
function PQftable; external 'libpq.dll';
function PQftablecol; external 'libpq.dll';
function PQfformat; external 'libpq.dll';
function PQftype; external 'libpq.dll';
function PQfsize; external 'libpq.dll';
function PQfmod; external 'libpq.dll';
function PQcmdStatus; external 'libpq.dll';
function PQoidValue; external 'libpq.dll';
function PQcmdTuples; external 'libpq.dll';
function PQgetvalue; external 'libpq.dll';
function PQgetlength; external 'libpq.dll';
function PQgetisnull; external 'libpq.dll';
function PQnparams; external 'libpq.dll';
function PQparamtype; external 'libpq.dll';
function PQdescribePrepared; external 'libpq.dll';
function PQdescribePortal; external 'libpq.dll';
function PQsendDescribePrepared; external 'libpq.dll';
function PQsendDescribePortal; external 'libpq.dll';
procedure PQclear; external 'libpq.dll';
procedure PQfreemem; external 'libpq.dll';
function PQmakeEmptyPGresult; external 'libpq.dll';
function PQcopyResult; external 'libpq.dll';
function PQsetResultAttrs; external 'libpq.dll';
function PQresultAlloc; external 'libpq.dll';
function PQsetvalue; external 'libpq.dll';
function PQescapeStringConn; external 'libpq.dll';
function PQescapeLiteral; external 'libpq.dll';
function PQescapeIdentifier; external 'libpq.dll';
function PQescapeByteaConn; external 'libpq.dll';
function PQunescapeBytea; external 'libpq.dll';
procedure PQprint; external 'libpq.dll';
function PQlibVersion; external 'libpq.dll';
function PQmblen; external 'libpq.dll';
function PQdsplen; external 'libpq.dll';
function PQenv2encoding; external 'libpq.dll';
function PQencryptPassword; external 'libpq.dll';
function pg_char_to_encoding; external 'libpq.dll';
function pg_encoding_to_char; external 'libpq.dll';
function pg_valid_server_encoding_id; external 'libpq.dll';

end.

