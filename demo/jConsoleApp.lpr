program jConsoleApp;

{ This is an example program that does basically the same thing
  as jconsole from the J distribution: read input, evaluate
  it, and print the result to standard output in a loop. }

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF} // why? (auto-generated)
  Classes, SysUtils, CustApp,
  jlang;

type

  { TJDemoApp }

  TJDemoApp = class(TCustomApplication)
  private
    fJL : TJLang;
  protected
    procedure DoRun; override;
    procedure JWr(s:PJS);
    function JRd(prompt:PJS):PJS;
    function JWd(x:TJI; a:PJA; var res:PJA) : TJI;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  end;

{ TJDemoApp }

procedure TJDemoApp.DoRun;
var
  ErrorMsg: String;
  line : String;
begin
  // quick check parameters
  ErrorMsg:=CheckOptions('h', 'help');
  if ErrorMsg<>'' then begin
    ShowException(Exception.Create(ErrorMsg));
    Terminate;
    Exit;
  end;

  // parse parameters
  if HasOption('h', 'help') then begin
    WriteHelp;
    Terminate;
    Exit;
  end;

  // main program
  // getdir(0,line); writeln('running in: ', line);
  jlang.Init('c:/program files/j902/bin/j.dll'); // TODO: customize. (env variable?)
  fJL := TJLang.Create(self);
  fJL.OnJWr := @JWr;
  fJL.OnJRd := @JRd;
  fJL.OnJWd := @JWd;
  repeat
    Write('  '); Readln(line);
    fJL.JDo(PChar(line));
  until line = 'bye';

  // stop program loop
  Terminate;
end;

procedure TJDemoApp.JWr(s: PJS);
begin WriteLn(s)
end;

var buf : string;
function TJDemoApp.JRd(prompt: PJS): PJS;
begin Write(prompt); ReadLn(buf); result := PJS(@buf);
end;

function TJDemoApp.JWd(x: TJI; a: PJA; var res: PJA): TJI;
begin
  writeln('Wd(x=', x, '  k: ',a^.k, ' flag: ',a^.flag, ' m: ',a^.m,
          ' t: ',a^.t, ' c: ',a^.c, ' n: ', a^.n, ' r: ',a^.r );
  result := 0
end;

constructor TJDemoApp.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
end;

destructor TJDemoApp.Destroy;
begin
  if Assigned(fJL) then fJL.Destroy;
  inherited Destroy;
end;

procedure TJDemoApp.WriteHelp;
begin
  { add your help code here }
  writeln('Usage: ', ExeName, ' -h');
end;

var
  Application: TJDemoApp;
begin
  Application:=TJDemoApp.Create(nil);
  Application.Title:='J Demo App';
  Application.Run;
  Application.Free;
end.

