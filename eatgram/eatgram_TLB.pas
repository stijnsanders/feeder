unit eatgram_TLB;

// ************************************************************************ //
// WARNING
// -------
// The types declared in this file were generated from data read from a
// Type Library. If this type library is explicitly or indirectly (via
// another type library referring to this type library) re-imported, or the
// 'Refresh' command of the Type Library Editor activated while editing the
// Type Library, the contents of this file will be regenerated and all
// manual modifications will be lost.
// ************************************************************************ //

// $Rev: 98336 $
// File generated on 7/07/2022 23:35:45 from Type Library described below.

// ************************************************************************  //
// Type Lib: D:\Data\2021\feeder\eatgram\eatgram (1)
// LIBID: {E400CD2D-FBDF-47A8-86E5-5C7F415E563D}
// LCID: 0
// Helpfile:
// HelpString:
// DepndLst:
//   (1) v2.0 stdole, (C:\Windows\SysWOW64\stdole2.tlb)
// SYS_KIND: SYS_WIN32
// ************************************************************************ //
{$TYPEDADDRESS OFF} // Unit must be compiled without type-checked pointers.
{$WARN SYMBOL_PLATFORM OFF}
{$WRITEABLECONST ON}
{$VARPROPSETTER ON}
{$ALIGN 4}

interface

uses Winapi.Windows, System.Classes, System.Variants, Vcl.OleServer, Winapi.ActiveX;


// *********************************************************************//
// GUIDS declared in the TypeLibrary. Following prefixes are used:
//   Type Libraries     : LIBID_xxxx
//   CoClasses          : CLASS_xxxx
//   DISPInterfaces     : DIID_xxxx
//   Non-DISP interfaces: IID_xxxx
// *********************************************************************//
const
  // TypeLibrary Major and minor versions
  eatgramMajorVersion = 1;
  eatgramMinorVersion = 0;

  LIBID_eatgram: TGUID = '{E400CD2D-FBDF-47A8-86E5-5C7F415E563D}';

  IID_IEaterGram: TGUID = '{1D1BFFF4-EDBF-455C-B70F-6049FCC3F1BD}';
  CLASS_EaterGram: TGUID = '{D1B22DA5-2714-442F-9D13-484D8766DAA8}';
type

// *********************************************************************//
// Forward declaration of types defined in TypeLibrary
// *********************************************************************//
  IEaterGram = interface;
  IEaterGramDisp = dispinterface;

// *********************************************************************//
// Declaration of CoClasses defined in Type Library
// (NOTE: Here we map each CoClass to its Default Interface)
// *********************************************************************//
  EaterGram = IEaterGram;


// *********************************************************************//
// Interface: IEaterGram
// Flags:     (4416) Dual OleAutomation Dispatchable
// GUID:      {1D1BFFF4-EDBF-455C-B70F-6049FCC3F1BD}
// *********************************************************************//
  IEaterGram = interface(IDispatch)
    ['{1D1BFFF4-EDBF-455C-B70F-6049FCC3F1BD}']
    function LoadData(const URL: WideString): WideString; safecall;
  end;

// *********************************************************************//
// DispIntf:  IEaterGramDisp
// Flags:     (4416) Dual OleAutomation Dispatchable
// GUID:      {1D1BFFF4-EDBF-455C-B70F-6049FCC3F1BD}
// *********************************************************************//
  IEaterGramDisp = dispinterface
    ['{1D1BFFF4-EDBF-455C-B70F-6049FCC3F1BD}']
    function LoadData(const URL: WideString): WideString; dispid 201;
  end;

// *********************************************************************//
// The Class CoEaterGram provides a Create and CreateRemote method to
// create instances of the default interface IEaterGram exposed by
// the CoClass EaterGram. The functions are intended to be used by
// clients wishing to automate the CoClass objects exposed by the
// server of this typelibrary.
// *********************************************************************//
  CoEaterGram = class
    class function Create: IEaterGram;
    class function CreateRemote(const MachineName: string): IEaterGram;
  end;

implementation

uses System.Win.ComObj;

class function CoEaterGram.Create: IEaterGram;
begin
  Result := CreateComObject(CLASS_EaterGram) as IEaterGram;
end;

class function CoEaterGram.CreateRemote(const MachineName: string): IEaterGram;
begin
  Result := CreateRemoteComObject(MachineName, CLASS_EaterGram) as IEaterGram;
end;

end.

