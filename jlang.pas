{$mode ObjFPC}{$H+}
unit JLang;

{ Object Pascal Interface to the J Programming Language.
  reference: https://code.jsoftware.com/wiki/Interfaces/JFEX }
interface

uses
  Classes, SysUtils, dynlibs;

{ call this to connect to J DLL }
procedure Init(libpath:UnicodeString);
{ same but use J_HOME environment variable }
function InitFromEnv:boolean;

{ a hook for using the component in Lazarus }
procedure Register;

type
  TJJ  = pointer;
  TJI  = Int64;
  PJS  = PAnsiChar;
  PJI  = ^TJI;
  PJA  = ^TJA;
  TJA  = record
           k,flag,m,t,c,n,r : TJI;
           s:pointer;
           v: array [0..0] of TJI; // really it's dynamically sized
         end;

  TJRdEvent = function(prompt:PJS):PJS of Object;
  TJWrEvent = procedure(s:PJS) of Object;
  TJWdEvent = function(x:TJI; a:PJA; var res:PJA) : TJI of Object;
  EJError = class(Exception);

  { TJLang }

  TJLang = class(TComponent)
  private
    fJJ : TJJ;
    fJRdEvent : TJRdEvent;
    fJWrEvent : TJWrEvent;
    fJWdEvent : TJWdEvent;
    procedure CheckJJ;
  protected
    function JGetLocale():PJS;
  public
    constructor Create(aOwner: TComponent); override;
    destructor Destroy; override;
    procedure JInit;
    procedure JFree;
    function JDo(s:String):TJI;
    function JGetM(id:PJS; out jtype,jrank:TJI; var jshape,jdata:PJI):TJI;
    function JGetA(id:String):PJA;
    function JSetA(n:TJI; id:PJS; x:TJI; data:PJS):TJI;
  published
    property OnJRd : TJRdEvent read fJRdEvent write fJRdEvent;
    property OnJWr : TJWrEvent read fJWrEvent write fJWrEvent;
    property OnJWd : TJWdEvent read fJWdEvent write fJWdEvent;
  end;

implementation

const
  ERR_CALL_INIT:String = 'Call jlang.Init(path) first!';
  ERR_CALL_JINIT:String = 'Call theJLang.JInit first!';
  ERR_PREV_JINIT:String = 'This TJLang component is already initialized!';

{-- J DLL Interface -----------------------------------------------------------}

{ Low-level interface if you just want to call J without using components }

type
  TJCBs  = array [0..4] of pointer; // callbacks
  TJInit = function : PJS; stdcall;
  TJSM   = procedure(j:TJJ; var cb:TJCBs); stdcall;
  TJDo   = function(j:TJJ; s:PJS):TJI; stdcall;
  TJFree = function(j:TJJ):TJI; stdcall;
  TJGetL = function(j:TJJ):PJS; stdcall;
  //  JGetM(JS jt, C* name, I* jtype, I* jrank, I* jshape, I* jdata)
  TJGetM = function(j:TJJ; id:PJS; out jtype,jrank:TJI; var jshape,jdata:PJI):TJI; stdcall;
  TJGetA = function(j:TJJ; n:TJI; name:PJS):PJA; stdcall;
  TJSetA = function(j:TJJ; n:TJI; name:PJS; x:TJI; data:PJS):TJI; stdcall;

{ stubs for when we are not connected to a dll }
{$WARN 5024 off : Parameter "$1" not used}
function xjInit : PJS; stdcall;
begin raise EJError.Create(ERR_CALL_INIT); result:=nil end;
procedure xjSM(j:TJJ; var cb:TJCBs); stdcall;
begin raise EJError.Create(ERR_CALL_INIT) end;
function xjDo(j:TJJ; s:PJS):TJI; stdcall;
begin raise EJError.Create(ERR_CALL_INIT); result := -1 end;
function xjFree(j:TJJ):TJI; stdcall;
begin raise EJError.Create(ERR_CALL_INIT); result := -1 end;
function xjGetL(j:TJJ):PJS; stdcall;
begin raise EJError.Create(ERR_CALL_INIT); result := nil end;
function xjGetM(j:TJJ; id:PJS; out jtype,jrank:TJI; var jshape,jdata:PJI):TJI; stdcall;
begin raise EJError.Create(ERR_CALL_INIT); result := -1 end;
function xjGetA(j:TJJ; n:TJI; name:PJS):PJA; stdcall;
begin raise EJError.Create(ERR_CALL_INIT); result := nil end;
function xjSetA(j:TJJ; n:TJI; name:PJS; x:TJI; data:PJS):TJI; stdcall;
begin raise EJError.Create(ERR_CALL_INIT); result := -1 end;
{$WARN 5024 on : Parameter "$1" not used}

var
  jLib   : TLibHandle;
  jHome  : UnicodeString = '';
  jjInit : TJInit = @xjInit;
  jjDo   : TJDo = @xjDo;
  jjSM   : TJSM = @xjSM;
  jjFree : TJFree = @xjFree;
  jjGetL : TJGetL = @xjGetL;
  jjGetM : TJGetM = @xjGetM;
  jjGetA : TJGetA = @xjGetA;
  jjSetA : TJSetA = @xjSetA;

procedure Init(libpath:UnicodeString);
begin
  JLib := LoadLibrary(libpath);
  if JLib = NilHandle then raise EJError.Create('failed to load '+String(libpath))
  else begin
    jHome  := ExtractFilePath(libPath);
    jjInit := TJInit(GetProcedureAddress(JLib, 'JInit'));
    jjSM   := TJSM(GetProcedureAddress(JLib, 'JSM'));
    jjDo   := TJDo(GetProcedureAddress(JLib, 'JDo'));
    jjFree := TJFree(GetProcedureAddress(JLib, 'JFree'));
    jjGetM := TJGetM(GetProcedureAddress(JLib, 'JGetM'));
    jjGetA := TJGetA(GetProcedureAddress(JLib, 'JGetA'));
    jjSetA := TJSetA(GetProcedureAddress(JLib, 'JSetA'));
    jjGetL := TJGetL(GetProcedureAddress(JLib, 'JGetLocale'));
    jjFree := TJFree(GetProcedureAddress(JLib, 'JFree'));
  end
end;

function InitFromEnv:Boolean;
  var home, dllPath : UnicodeString;
begin
  home := GetEnvironmentVariable(UnicodeString('J_HOME'));
  if home = '' then Exit(false);
  dllPath := home + '/j.dll';
  if not FileExists(dllPath) then Exit(false);
  result := true; Init(dllPath)
end;


{-- Pointer Map ---------------------------------------------------------------}

{ The J callbacks send back a TJJ, but there's no room in the protocol
  to hold a pointer back to the corresponding TComponent. So, on the
  assumption that there will probably only be a handful of TJLang instances,
  we keep our own mapping from TJJ -> TJLang in an array array. }

type
  TJToPas = record j:TJJ; pas: TJLang end;

var jToPas: Array of TJToPas;

function j2p(jj:TJJ):TJLang;
var rec : TJToPas;
begin
  for rec in jToPas do if (rec.j = jj) and Assigned(rec.pas) then exit(rec.pas);
  raise EJError.Create('No matching JLang Component found!')
end;


procedure DoWr(jj : TJJ; {%H-}len:TJI; s:PJS); stdcall;
var jl : TJLang;
begin jl := j2p(jj);
  if Assigned(jl.OnJWr) then jl.OnJWr(s)
end;

function DoRd(jj:TJJ; prompt:PJS):PJS; stdcall;
var jl : TJLang;
begin jl := j2p(jj);
  if Assigned(jl.OnJRd) then result := jl.OnJRd(prompt)
  else result := Nil
end;

function DoWd(jj : TJJ; x:TJI; a:PJA; var res:PJA) : TJI; stdcall;
var jl : TJLang;
begin jl := j2p(jj);
  { writeln('Wd: x=', x, '  k: ',a^.k, ' flag: ',a^.flag, ' m: ',a^.m,
     t: ',a^.t, ' c: ',a^.c, ' n: ',a^.n, ' r: ',a^.r ); }
  if Assigned(jl.OnJWd) then result := jl.OnJWd(x, a, res)
  else result := 0
end;


{-- TJLang --------------------------------------------------------------------}

constructor TJLang.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  if jlib <> NilHandle then JInit;
end;

destructor TJLang.Destroy;
begin
  if Assigned(fJJ) then JFree;
  inherited Destroy;
end;

procedure TJLang.JInit;
  var rec:TJToPas; jcb:TJCBs=(@DoWr, @DoWd, @DoRd, Nil, Pointer(3));
begin
  if Assigned(fJJ) then raise EJError.Create(ERR_PREV_JINIT);
  if jlib = NilHandle then raise EJError.Create(ERR_CALL_INIT);
  fJJ := jjInit(); jjSM(fJJ, jcb);
  rec.j := fJJ; rec.pas := self;
  insert(rec, jToPas, length(jToPas));
  JDo('ARGV_z_=:,<''''');
  JDo('BINPATH_z_ =: }:^:(''/''={:)' + QuotedStr(AnsiString(jHome)));
  JDo('0!:0<BINPATH_z_,''/profile.ijs''');
end;

procedure TJLang.JFree;
  var i : integer;
begin
  if not Assigned(fJJ) then Exit;  // !! maybe a warning here?
  jjFree(fJJ);
  for i := 0 to Length(jToPas) do if jToPas[i].pas = self then begin
    Delete(jToPas, i,1); break
  end;
end;

procedure TJLang.CheckJJ;
begin if not Assigned(fJJ) then raise EJError.Create(ERR_CALL_JINIT);
end;

function TJLang.JDo(s: String): TJI;
begin checkJJ; result := jjDo(fJJ, PJs(s))
end;

function TJLang.JGetM(id: PJS; out jtype, jrank:TJI; var jshape, jdata: PJI): TJI;
begin CheckJJ; result := jjGetM(fJJ, id, jtype, jrank, jshape, jdata)
end;

function TJLang.JGetLocale: PJS;
begin checkJJ; result := jjGetL(fJJ)
end;

function TJLang.JGetA(id: String): PJA;
begin checkJJ; result := jjGetA(fJJ, length(id), PJS(id))
end;

function TJLang.JSetA(n: TJI; id: PJS; x: TJI; data: PJS): TJI;
begin result := jjSetA(fJJ, n, id, x, data)
end;


{-- Lazarus Integration -------------------------------------------------------}

procedure Register;
begin
  RegisterComponents('Misc',[TJLang]);
end;

end.

