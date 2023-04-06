{$mode ObjFPC}{$H+}
unit JLang;

{ Object Pascal Interface to the J Programming Language
  reference: https://code.jsoftware.com/wiki/Interfaces/JFEX }

interface

uses
  Classes, SysUtils, dynlibs;

{ call this to connect to J DLL }
procedure Init(libpath:PChar);

{ a hook for using the component in Lazarus }
procedure Register;

type
  TJJ  = pointer;
  TJI  = Int32;
  PJS  = PAnsiChar;
  PJA  = ^TJA;
  TJA  = record
           k,flag,m,t,c,n,r,s : TJI;
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
  protected
    function JGetLocale():PJS;
  public
    constructor Create(aOwner: TComponent); override;
    destructor Destroy; override;
    function JDo(s:PJS):TJI;
    function JGetA(n:TJI; id:PJS):PJA;
    function JSetA(n:TJI; id:PJS; x:TJI; data:PJS):TJI;
  published
    property OnJRd : TJRdEvent read fJRdEvent write fJRdEvent;
    property OnJWr : TJWrEvent read fJWrEvent write fJWrEvent;
    property OnJWd : TJWdEvent read fJWdEvent write fJWdEvent;
  end;

implementation

{-- J DLL Interface -----------------------------------------------------------}

{ Low-level interface if you just want to call J without using components }

type
  TJCBs  = array [0..4] of pointer; // callbacks
  TJInit = function : PJS; stdcall;
  TJSM   = procedure(j:TJJ; var cb:TJCBs); stdcall;
  TJDo   = function(j:TJJ; s:PJS):TJI; stdcall;
  TJFree = function(j:TJJ):TJI; stdcall;
  TJGetL = function(j:TJJ):PJS; stdcall;
  TJGetA = function(j:TJJ; n:TJI; name:PJS):PJA; stdcall;
  TJSetA = function(j:TJJ; n:TJI; name:PJS; x:TJI; data:PJS):TJI; stdcall;
var
  JLib   : TLibHandle;
  jjInit  : TJInit;
  jjDo   : TJDo;
  jjSM   : TJSM;
  jjFree : TJFree;
  jjGetL : TJGetL;
  jjGetA : TJGetA;
  jjSetA : TJSetA;

procedure Init(libpath:PChar);
begin
  JLib := LoadLibrary(libpath);
  if JLib = NilHandle then raise EJError.Create('failed to load '+libpath)
  else begin
    jjInit := TJInit(GetProcedureAddress(JLib, 'JInit'));
    jjSM   := TJSM(GetProcedureAddress(JLib, 'JSM'));
    jjDo   := TJDo(GetProcedureAddress(JLib, 'JDo'));
    jjFree := TJFree(GetProcedureAddress(JLib, 'JFree'));
    jjGetA := TJGetA(GetProcedureAddress(JLib, 'JGetA'));
    jjSetA := TJSetA(GetProcedureAddress(JLib, 'JSetA'));
    jjGetL := TJGetL(GetProcedureAddress(JLib, 'JGetLocale'));
  end
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
var rec:TJToPas; jcb:TJCBs=(@DoWr, @DoWd, @DoRd, Nil, Pointer(3));
begin
  if jlib = NilHandle then raise EJError.Create('Call jlang.Init(libPath) first!');
  inherited Create(aOwner);
  fJJ := jjInit(); jjSM(fJJ, jcb);
  rec.j := fJJ; rec.pas := self;
  insert(rec, jToPas, length(jToPas))
end;

destructor TJLang.Destroy;
var i : integer;
begin jjFree(fJJ);
  for i := 0 to Length(jToPas) do if jToPas[i].pas = self then begin
    Delete(jToPas, i,1); break
  end;
  inherited Destroy;
end;

function TJLang.JDo(s: PJS): TJI;
begin result := jjDo(fJJ, s)
end;

function TJLang.JGetLocale: PJS;
begin result := jjGetL(fJJ)
end;

function TJLang.JGetA(n: TJI; id: PJS): PJA;
begin result := jjGetA(fJJ, n, id)
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

