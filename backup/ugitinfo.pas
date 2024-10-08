unit uGitInfo;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

type

  { TGitInfo }

  TGitInfo=class
  public
    function GetGitPath: string;
  end;

implementation

uses registry;

{ TGitInfo }

function TGitInfo.GetGitPath: string;
var
  reg: TRegistry;
  gitpath: string;
begin
  reg:= TRegistry.Create();
  try
     reg.RootKey:= HKEY_CURRENT_USER;
     if reg.OpenKeyReadOnly('\SOFTWARE\GitForWindows\') then
        gitpath:= reg.ReadString('InstallPath');
  finally
    reg.Free;
  end;
  Result:= gitpath;
end;

end.

