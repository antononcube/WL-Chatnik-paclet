
BeginPackage["AntonAntonov`Chatnik`PromptExpander`"];

Begin["`Private`"];

Needs["AntonAntonov`Chatnik`"];

(**************************************************************)
(* Parsers / extractors                                       *)
(**************************************************************)

pmtParamSimple = Except[WhitespaceCharacter | "^" | "|" | "="] ..;

pmtParamQuoted = 
  StringExpression[("\"" ~~ Shortest[Except["\""] ..] ~~ "\"") | ("'" ~~ Shortest[Except["'"] ..] ~~ "'")];

pmtParam = pmtParamQuoted | pmtParamSimple;

pmtListOfParams = pmtParam ~~ ("|" ~~ pmtParam) ...;

pmtPersona = 
  matched: StringExpression[
    StartOfString,
    (WhitespaceCharacter ...), 
    "@", 
    name : (WordCharacter ..),
    RepeatedNull[
      "|" ~~ params : pmtListOfParams
    ], 
    ("|" ...) 
  ] :> <|"matched" -> matched, "name" -> name, "params" -> params|>;

pmtModifier = 
  matched:( "#" ~~ name : (LetterCharacter ..) ~~ ("|" ~~ params : pmtListOfParams ~~ ("|") ...) ... ):> <|"matched" -> matched, "name" -> name, "params" -> params|>;

pmtFunction = 
  matched:( ("!" | "&") ~~ name : (WordCharacter ..) ~~ "|" ~~ params : pmtListOfParams ~~ ("|" ...) ):> <|"matched" -> matched, "name" -> name, "params" -> params|>;

pmtFunctionCell = 
  matched: StringExpression[
    StartOfString, 
    WhitespaceCharacter ..., 
    ("!" | "&"),
    name : LetterCharacter .., 
    RepeatedNull["|" ~~ params : pmtListOfParams ~~ RepeatedNull["|"]],
    RepeatedNull[WhitespaceCharacter .. | ">"], cellArg__
  ] :> <|"matched" -> matched, "name" -> name, "params" -> params, "cellArg" -> cellArg|>;

pmtFunctionPrior =
  matched: StringExpression[
    StartOfString,
    WhitespaceCharacter ...,
    ("!" | "&"),
    name : (WordCharacter ..),
    "|", 
    params : pmtListOfParams, 
    ("|" ...),
    pointer : ("^" ..), 
    WhitespaceCharacter ...,
    EndOfString 
  ] :> <|"matched" -> matched, "name" -> name, "params" -> params, "pointer" -> pointer|>;

pmtAny = 
  Alternatives[pmtPersona, pmtFunctionPrior, pmtFunction, pmtFunctionCell, pmtModifier];

aParsers = 
  AssociationThread[{"Persona", "FuncPrior", "Func", "FuncCell", "Modifier"}, List @@ pmtAny];

(*------------------------------------------------------------*)
(* Remove quotes                                              *)
(*------------------------------------------------------------*)

ToUnquoted[ss_String] := Module[{s = ss},
  Which[
    StringMatchQ[s, "'" ~~ ___ ~~ "'"], StringTake[s, {2, -2}],
    StringMatchQ[s, "\"" ~~ ___ ~~ "\""], StringTake[s, {2, -2}],
    StringMatchQ[s, "⎡" ~~ ___ ~~ "⎦"], StringTake[s, {2, -2}],
    True, s
  ]
];

ParseParams[str_] := If[StringQ[str], Map[ToUnquoted, Select[StringSplit[str, "|"], # =!= "" &]], {}];

(*------------------------------------------------------------*)
(* Main parser                                                *)
(*------------------------------------------------------------*)

PromptFunctionSpec[input_?StringQ, parsed_?AssociationQ, messages_ : {}, sep_ : "\n"] := 
  Module[{matched, name, params, cellArg, args = {}, p, end = sep},
  
    matched = Lookup[parsed, "matched", ""];
    name = Lookup[parsed, "name", ""];
    params = Lookup[parsed, "params", ""];
    cellArg = Lookup[parsed, "cellArg", ""];
    
    (* No changes to the input of no prompt is found *)
    If[StringLength[matched] == 0 || StringLength[name] == 0 || Length[ChatnikPromptRecords[name]] == 0,
      Return[input]
    ];
  
    (* Known prompt template *)
    p = LLMPrompt[name];

    (*Prepare template to arguments*)
    args = StringTrim /@ StringSplit[params, "|"];
    args = ToUnquoted /@ args;

    If[StringLength[cellArg] > 0,
      args = Append[args, cellArg] 
    ];

    (* Process pointer if any *)
    If[KeyExistsQ[parsed, "pointer"] && Length[messages] > 0,
      Which[  
        parsed["pointer"] == "^",
        args = Append[args, Last @ messages],

        parsed["pointer"] == "^^",
        args = Append[args, StringRiffle[messages, sep]]
      ]
    ];

    (* Apply template to arguments *)
    StringReplace[input, matched -> TemplateApply[p, args]]
  ];

ChatnikPromptExpand[input_?StringQ, messages_: {}, sep_ : "\n"] :=
  Module[{lsParsed, res = input},
    (* This single pass parsing is somewhat deficient, but works for most cases. *)

    Map[(
      lsParsed = StringCases[res, aParsers[#]];
      If[Length[lsParsed] > 0, 
        res = Fold[PromptFunctionSpec[#1, #2, messages, sep]&, res, lsParsed]
      ]
    )&, {"Persona", "FuncPrior", "FuncCell", "Func", "Modifier"}];

    res
  ];

End[];
EndPackage[];    