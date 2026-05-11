
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
  StringExpression[
    StartOfString,
    (WhitespaceCharacter ...), 
    "@", 
    name : (WordCharacter ..),
    RepeatedNull[
      "|" ~~ params : pmtListOfParams
    ], 
    ("|" ...) 
  ] :> <|"name" -> name, "params" -> params|>;

pmtModifier = 
  "#" ~~ name : (LetterCharacter ..) ~~ ("|" ~~ params : pmtListOfParams ~~ ("|") ...) ... :> <|"name" -> name, "params" -> params|>;

pmtFunction = ("!" | "&") ~~ name : (WordCharacter ..) ~~ "|" ~~ params : pmtListOfParams ~~ ("|" ...) :> <|"name" -> name, "params" -> params|>;

pmtFunctionCell = 
  StringExpression[
    StartOfString, 
    WhitespaceCharacter ..., 
    ("!" | "&"),
    name : LetterCharacter .., 
    RepeatedNull["|" ~~ params : pmtListOfParams ~~ RepeatedNull["|"]],
    RepeatedNull[WhitespaceCharacter .. | ">"], cellArg__
  ] :> <|"name" -> name, "params" -> params, "cellArg" -> cellArg|>;

pmtFunctionPrior =
  StringExpression[
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
  ] :> <|"name" -> name, "params" -> params, "pointer" -> pointer|>;

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

PromptFunctionSpec[assoc_, messages_, sep_] := 
  Module[{name, params = {}, args = {}, p, end = sep},
  
  Nothing
];

ChatnikPromptExpansion[input_String, messages_: {}, sep_ : "\n"] :=
  StringReplace[
   input,
   pmtAnyPattern :>
     With[{a = Association[Rest @ StringCases[#, Rule[_, _], Overlaps -> True]] &},
       PromptFunctionSpec[a@#, messages, sep]
     ]
  ];

End[];
EndPackage[];    