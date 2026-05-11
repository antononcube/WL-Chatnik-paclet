(* ::Package:: *)

BeginPackage["AntonAntonov`Chatnik`Scraper`"];

Begin["`Private`"];

Needs["AntonAntonov`Chatnik`"];

ClearAll[allURL, ResourceURLQ, GetLinksWithBrowser, GetPromptInfo, ScrapePromptRecords];

allURL = "https://resources.wolframcloud.com/PromptRepository/all";

ResourceURLQ[url_String] := StringContainsQ[url, "/PromptRepository/resources/"];

(*1. Use a browser session because the listing page is JS-heavy.*)
GetLinksWithBrowser[url_] := 
  Module[{session, links}, session = StartWebSession["Chrome"];
   WebExecute[session, "OpenPage" -> url];
   Pause[5];
   links = 
    WebExecute[session, 
     "JavascriptExecute" -> 
      "return Array.from(document.querySelectorAll('a'))
        .map(a => a.href)
        .filter(h => h.includes('/PromptRepository/resources/'));"];
   DeleteObject[session];
   DeleteDuplicates@Select[links, resourceURLQ]
 ];

GetPromptInfoFromPage[url_String] := 
 Module[{xmlObj,t,title,description}, xmlObj = Import[url, "XMLObject"];

    t = Cases[xmlObj, XMLElement["title", ___], Infinity];
    title = If[ Length[t]>0, First@StringSplit @ t[[1, 3, 1]], Missing["NotFound"]];

    t = Cases[xmlObj, XMLElement["meta", {"name" -> "description", ___}, ___], Infinity];
    description =
        If[Length[t] > 0,
        First@Cases[t, HoldPattern["content" -> descr_] :> descr, Infinity],
        (*ELSE*)
        Missing["NotFound"]
    ];

    <|"Name" -> title, "Description" -> description, "URL" -> url|>
 ];

ScrapePromptRecords[url_: allURL]:=
    Module[{links,records},
        links = GetLinksWithBrowser[url];
        records = GetPromptInfoFromPage /@ links;
        records
    ];

End[];
EndPackage[];    
