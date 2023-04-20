{$mode ObjFPC}{$H+}
unit ujkvm;

{ This is a component that draws a text terminal with fixed width text
  and 24-bit color. It currently handles only ASCII characters and does
  not actually know anything about its contents.

  The main purpose is to render console widgets created with j-kvm:
  https://github.com/tangentstorm/j-kvm }

interface

uses
  Classes, SysUtils, Controls, Graphics,
  LazFreeTypeFontCollection, LazLogger,
  BGRABitmap, BGRABitmapTypes, BGRATextFX;

type

  { TJKVM }

  TJKVM = class(TCustomControl)
  private
    fFontName : string;
    fFontH, fCharW, fCharH: byte;
    fBmp, fTmp : TBGRABitmap;
    fFnt:Array[byte] of TBGRABitmap;
    function GetGridH: byte;
    function GetGridW: byte;
    procedure SetFontH(AValue: byte);
  protected
    procedure BoundsChanged; override;
    procedure Paint; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure DrawChar(x,y:integer; ch:WideChar; fg,bg:TColor);
    procedure Clear(const bg:TColor=$333333);
    procedure Rnd;
  published
    property FontName:string read fFontName write fFontName;
    property FontH:byte read fFontH write SetFontH default 24;
    property GridW:byte read GetGridW;
    property GridH:byte read GetGridH;
    property Left; property Top;  property Width; property Height;
    property Align;
    property Anchors;
    property Constraints;
    property DragCursor;
    property DragMode;
    property Enabled;
    property Font;
    property OnChangeBounds;
    property OnClick;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnStartDrag;
    property OnUTF8KeyPress;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('Misc',[TJKVM]);
end;

{ TJKVM }

constructor TJKVM.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  fCharW:=15; fCharH:=29; fFontName := 'Fira Mono'; SetFontH(24);
  BoundsChanged; { to init fBmp }
end;

destructor TJKVM.Destroy;
begin
  fBmp.Free;
  inherited Destroy;
end;

// we support a subset of unicode characters. mostly box-drawing characters.
// this maps the codepoint to the corresponding index in the bitmap font.
function SymbolToIndex(codepoint:word):byte;
begin
 case codepoint of
   32..127: result := codepoint;
   // line drawing characters:
   $250c: result := 16;
   $252c: result := 17;
   $2510: result := 18;
   $251c: result := 19;
   $253c: result := 20;
   $2524: result := 21;
   $2514: result := 22;
   $2534: result := 23;
   $2518: result := 24;
   $2502: result := 25;
   $2500: result := 26;
   $2580: result := 127; // half-box character
   $25A1: result := 255; // white box: the "missing character" character
   otherwise result := byte(255);
 end;
end;

procedure TJKVM.SetFontH(AValue: byte);
  var i : byte; cp: word;
  // special symbols, including the 11 box drawing characters that j uses.
  const symbols: array of word = (
    $250c, $252c, $2510, $251c, $253c, $2524,
    $2514, $2534, $2518, $2502, $2500, $25A1);

  procedure MakeBitmapChar(ix:byte; s:WideString);
  begin
    with fFnt[SymbolToIndex(ord(s[1]))] do begin
      FontName := fFontName;
      FontHeight := fFontH;
      FontQuality := fqSystemClearType;
      FontAntialias:= true;
      TextOut(0,0, UTF8Encode(s), BGRAWhite);
    end;
  end;

begin
  if (fFontH=AValue) and (Assigned(fTmp)) then Exit;
  fFontH:=AValue;
  if Assigned(fTmp) then begin
    fTmp.Free;
    for i := 0 to 255 do fFnt[i].Free;
  end;
  for i := 0 to 255 do fFnt[i] := TBGRABitmap.Create(fCharW,fCharH, BGRAPixelTransparent);
  for i := 32 to 126 do MakeBitmapChar(i, chr(i));
  for cp in symbols do MakeBitmapChar(SymbolToIndex(cp), WideChar(cp));
  // 127 is cp $2580 : the half-box drawing character. i just drew it myself.
  fFnt[127].FillRect(0, 0, fCharW, fCharH div 2, BGRAWhite);
  fTmp := TBGRABitmap.Create(fCharW,fCharH, BGRAPixelTransparent);
end;

function TJKVM.GetGridH: byte;
begin result := Height div fCharH
end;

function TJKVM.GetGridW: byte;
begin result := Width  div fCharW
end;

procedure TJKVM.BoundsChanged;
begin
  inherited BoundsChanged;
  if Assigned(fBmp) then fBmp.free;
  fBmp:= TBGRABitmap.Create(ClientWidth, ClientHeight, BGRAPixelTransparent);
  Clear;
end;

procedure TJKVM.Paint;
begin fBmp.Draw(Canvas, 0, 0, true);
end;


procedure TJKVM.DrawChar(x, y: integer; ch: WideChar; fg, bg: TColor);
  var r,w: PBGRAPixel; i:word; ix:byte;
begin
  ix := SymbolToIndex(ord(ch));
  fBmp.FillRect(x*fCharW, y*fCharH, (x+1)*fCharW, (y+1)*fCharH, bg);
  // make a new colored char with alpha
  r := fFnt[ix].Data; w := fTmp.Data;
  for i := fTmp.NbPixels-1 downto 0 do begin
    w^ := fg;  w^.alpha := r^.alpha;
    inc(r); inc(w);
  end;
  fTmp.InvalidateBitmap;
  fBmp.PutImage(x*fCharW, y*fCharH, fTmp, dmDrawWithTransparency);
end;

procedure TJKVM.Clear(const bg: TColor);
begin fBmp.FillRect(0, 0, fBmp.Width, fBmp.Height, bg, dmSet);
end;

{ Fill entire area with random colored characters }
procedure TJKVM.Rnd;
  var x,y:Integer;
begin
  Clear;
  for y := 0 to GridH-1 do for x := 0 to GridW-2 do begin
    DrawChar(x, y, chr(33+byte(Random(94))), Random($ffffff), BGRABlack);
  end;
end;

end.

