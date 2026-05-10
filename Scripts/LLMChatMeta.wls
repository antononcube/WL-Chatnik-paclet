#!/usr/local/bin/wolframscript

Needs["AntonAntonov`Chatnik`"];
Needs["Wolfram`CommandLineParser`"];

(*-------------------------------------------------------------*)
(* CLI argument parsing specs                                  *)
(*-------------------------------------------------------------*)

posArgSpecs = {"command" -> 
    StringSpec["Command, one of: card, clear, context, delete, file, first-message, last-message, list, load-llm-personas, message, messages."]
};

optArgSpecs = {
   {"chat-id", ""} -> StringSpec["Chat ID."],
   {"id", ""} -> StringSpec["Chat ID. (Ignored if --chat-id is present.)"],
   {"i", ""} -> StringSpec["Chat ID. (Ignored if --chat-id or --id are present.)"],
   {"all", "false"} -> BooleanSpec["Whether to apply the command to all chat objects or not."],
   {"n", "-Infinity"} -> NumericSpec["Integer", "Messages to clear. (For 'clear' and 'messages' only.)", "Interval" -> {-Infinity, Infinity}, "AllowInfinity" -> True],
   {"index", "-1"} -> NumericSpec["Integer", "Message index. (For 'message' only)", "Interval" -> {-Infinity, Infinity}, "AllowInfinity" -> True],
   {"format", ""} -> StringSpec["Format of the result. (For 'list' and 'context' only.)"]
};

helpHeader = "Chat with persistent LLM-chat objects.";

spec = {posArgSpecs, optArgSpecs, helpHeader};

res = ParseCommandLine[spec, Rest@$ScriptCommandLine];

command = ToLowerCase @ res[[1]]["command"];
opts = res[[2]];

(*-------------------------------------------------------------*)
(* Using stdout for results and stderr for reported errors     *)
(*-------------------------------------------------------------*)
Say[x_] := WriteString[OutputStream["stdout", 1], x <> "\n"];
Proclaim[x_] := WriteString[OutputStream["stderr", 2], x <> "\n"];

CannotFind[x_] := If[StringLength[StringTrim@x]>0, 
        Proclaim["Cannot find the chat object " <> x],
        Proclaim["No chat ID is specified"]
];

delimThick = StringJoin @@ Table["=", 60];
delimThin = StringJoin @@ Table["-", 60];

(*-------------------------------------------------------------*)
(* Get n range                                                 *)
(*-------------------------------------------------------------*)
GetNRange[n_, elems_Integer] :=
  Module[{min = 1, max = elems},
    If[IntegerQ[n],
       If[n >= 1, max = n, min = Max[elems + n + 1, 1]]
    ];
    <|"min" -> min, "max" -> max|>
];

(*-------------------------------------------------------------*)
(* Process commands                                            *)
(*-------------------------------------------------------------*)
If[
    MemberQ[{"delete", "drop"}, command] && opts["all"],
    PersistentSymbol["ChatnikChats"] = <||>;
    Proclaim["Deleted all chat objects."];
    Exit[0]
];

aChats = PersistentSymbol["ChatnikChats"];
chatID = Which[
    StringTrim[opts["chat-id"]] != "", opts["chat-id"],
    StringTrim[opts["id"]] != "", opts["id"], 
    True, StringTrim[opts["i"]] 
];

If[Length[aChats] == 0,
    Proclaim["No chat objects."];
    Exit[0]
];

Which[
    MemberQ[{"list", "personas", "chats", "chat-objects", "chatobjects"}, command],
    aRes = Map[
        <|"ChatID" -> #["ChatID"], 
          "Messages" -> Length[#["Messages"]], 
          "LLMConfiguration" -> KeyTake[#["LLMEvaluator"]["Model"], {"Service", "Name"}], 
          "Usage" -> ToString[#["Usage"]]|> &, 
        aChats
    ];
    Say @ If[ToLowerCase[opts["format"]] == "json", ExportString[aRes, "RawJSON"], ToString @ InputForm[aRes]],

    MemberQ[{"delete", "drop"}, command],
    If[KeyExistsQ[aChats, chatID],
        PersistentSymbol["ChatnikChats"] = KeyDrop[aChats, chatID],
        (*ELSE*)
        CannotFind[chatID]
    ],
    
    MemberQ[{"clear", "clear-messages", "clearmessages"}, command] && opts["all"],
    aChats = Map[ChatnikClearMessages[#, All]&, aChats];
    PersistentSymbol["ChatnikChats"] = aChats,

    MemberQ[{"clear", "clear-messages", "clearmessages"}, command],
    If[KeyExistsQ[aChats, chatID],
        {min, max} = Values @ KeyTake[GetNRange[opts["n"], Length @ aChats[chatID]["Messages"]], {"min", "max"}];
        aChats[chatID] = ChatnikClearMessages[aChats[chatID], {min, max}];
        PersistentSymbol["ChatnikChats"] = aChats;
        ins = If[min == max, "message " <> ToString[min], "messages from " <> ToString[min] <> " to " <> ToString[max]];
        Proclaim["Cleared the " <> ins <> " of chat object " <> chatID <> "."]
        ,
        (* ELSE *)
        CannotFind[chatID]
    ],

    MemberQ[{"first-message", "firstmessage", "last-message", "lastmessage"}, command] && !opts["all"],
    If[KeyExistsQ[aChats, chatID],
        If[Length[aChats[chatID]["Messages"]] > 0, 
            i = If[StringStartsQ[command, "first"], 1, -1];
            m = aChats[chatID]["Messages"][[i]];
            m = StringRiffle[Map[#["Data"]&, m["Content"]], "\n"];
            Say[m],
            (*ELSE*)
            Proclaim["The chat object " <> chatID <> " has no messages."]
        ],
        (* ELSE *)
        CannotFind[chatID]
    ],

    MemberQ[{"messages", "full-text", "fulltext"}, command] && opts["all"],
    KeyValueMap[(Say[delimThick]; Say["Chat ID : " <> #1 <> "\n"]; Say[delimThin]; Say[#2["FullText"]])&, aChats],

    MemberQ[{"messages", "full-text", "fulltext"}, command],
    If[KeyExistsQ[aChats, chatID],
        Say[aChats[chatID]["FullText"]],
        (* ELSE *)
        CannotFind[chatID]
    ],

    True,
    Proclaim["Do not know how to process the given command."]
]