#!/usr/local/bin/wolframscript --function
Function[
    Block[{slots},
        args = {##};
        If[Length[args] < 1, 
            "At least one argument is expected.",
            (*ELSE*)
            slots = DeleteDuplicates@Cases[LLMPrompt[#1], HoldPattern[ts : TemplateSlot[slot_, rest___]] :> slot, Infinity];
            If[Length[slots] > 0 && Length[args] > 1, 
                LLMPrompt[First @ args][Sequence @@ Rest[args]], 
                (*ELSE*)
                LLMPrompt[First @ args][]
            ]
        ]
    ]    
]