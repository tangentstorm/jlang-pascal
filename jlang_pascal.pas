{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit jlang_pascal;

{$warn 5023 off : no warning about unused units}
interface

uses
  ujlang, ujkvm, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('ujlang', @ujlang.Register);
  RegisterUnit('ujkvm', @ujkvm.Register);
end;

initialization
  RegisterPackage('jlang_pascal', @Register);
end.
