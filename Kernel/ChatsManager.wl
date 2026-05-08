(**************************************************************)
(* Package definition                                         *)
(**************************************************************)

BeginPackage["AntonAntonov`Chatnik`ChatsManager`"];

Begin["`Private`"];

Needs["AntonAntonov`Chatnik`"];

GetProviderAndModel[spec_String] := 
  Module[{provider, model}, 
   If[StringContainsQ[spec, "::"], 
    {provider, model} = StringSplit[spec, "::"];
    provider =
      Switch[ToLowerCase[provider],
        "chatgpt", "OpenAI",
        "google", "Gemini",
        "ollama", "Ollama",
        "chatollama", "Ollama",
        _, provider
        ];
    <|"Service" -> provider, "Name" -> model|>,
    (*ELSE*)
    <|"Service" -> "OpenAI", "Name" -> spec|>
    ]
   ];

Clear[LLMConfigurationByArgs];
LLMConfigurationByArgs[args_Association] :=
  Module[{knownParamNames, confArgs, unknown, spec, confArgs2},

   knownParamNames = {"MaxTokens", "Model", "PromptDelimiter", 
     "Prompts", "Reasoning", "StopTokens", "Temperature", "ToolMethod",
      "Tools", "TopProbabilities", "TotalProbabilityCutoff"};
   
   confArgs = KeyTake[args, knownParamNames];
   
   If[Length[args] > Length[confArgs], 
     unknown = Keys@KeySelect[args, (! MemberQ[knownParamNames, #]) && (!MemberQ[{"i", "id", "chat-id", "prompt"}, #]) &];
    
     If[Length[unknown] > 0,
       Echo["Unknown LLM configuration option" <> If[Length[unknown] > 1, "s", ""] <> ": '" <> StringRiffle[unknown, ", "] <> "'.", "Chatnik:"]
     ]
   ];
   
   If[! KeyExistsQ[confArgs, "Model"] && Environment["CHATNIK_DEFAULT_MODEL"] =!= $Failed, 
    confArgs["model"] = Environment["CHATNIK_DEFAULT_MODEL"]
   ];
   
   If[KeyExistsQ[confArgs, "Model"],
     spec = GetProviderAndModel[confArgs["Model"]];
     confArgs["Service"] = spec["Service"];
     confArgs["Name"] = spec["Name"];
  ];
   
   confArgs2 = KeyDrop[confArgs, {"Service", "Name", "Model"}];
   LLMConfiguration[Join[<|"Model" -> {confArgs["Service"], confArgs["Name"]}|>, confArgs2]]
];

Clear[ChantikEvaluate];
ChatnikEvaluate[input_?StringQ, aArgs_?AssociationQ, location_ : "Local"] :=
  Module[{aChats, chatID, prompt, conf, chatObj, sep, resObj, ans},
   
   (*Get persistent chats*)
   aChats = PersistentSymbol["ChatnikChats", location];
   If[! AssociationQ[aChats], aChats = <||>];
   
   (*Get chat ID*)
   chatID = Lookup[aArgs, "chat-id", Lookup[aArgs, "id", Lookup[aArgs, "i", "NONE"]]];
   
   (*Get prompt*)
   prompt = Lookup[aArgs, "prompt", Nothing];
   
   (*Warn if an existing chat-
   id is used and are also given a prompt and configuration spec*)
   If[(StringQ[prompt] || Length[KeyDrop[aArgs, {"chat-id", "id", "i"}]] > 0) && KeyExistsQ[aChats, chatID],
     Echo[
       StringTemplate["No new chat object is created.\nUsing chat object with id: ⎡`1`⎦, and number of messages: `2`"][chatID, Length@aChats[chatID]["Messages"]],"Chatnik:"]
   ];
   
   (*Create an LLM configuration*)
   conf = LLMConfigurationByArgs[KeyDrop[aArgs, {"chat-id", "id", "i"}]];
   
   (*Get chat object*)
   chatObj = Lookup[aChats, chatID, ChatObject[prompt, LLMEvaluator -> conf]];
   
   (*We can get a delimiter from the configuration.
   But for prompt expansions it is most like better to use new line.*)
   sep = "\n";
   
   (*Evaluate message*)
   resObj = Enclose[Confirm[ChatEvaluate[chatObj, input]]];
   
   (*Register*)
   aChats[chatID] = resObj;
   PersistentSymbol["ChatnikChats", location] = aChats;
   
   (*Result*)
   ans = Last@resObj["Messages"];
   If[KeyExistsQ[ans, "Content"],
     ans = StringRiffle[Map[First@KeyDrop[#, "Type"] &, Select[ans["Content"], #["Type"] == "Text" &]], sep]
   ];
   ans
];

ChatnikEvaluate[___]:=(Echo["The first argument is expected to be a string, the second argument is expected to be an association.", "Chatnik:"]; $Failed);

End[]; (*`Private`*)

EndPackage[]