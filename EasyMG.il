; skill load "EasyMG.il"
; Form rules:
;	- every non-blank line must have a tab character
;	- any quote must be escaped (e.g. use the backslash '\')
;	- any paraenthesis '()' must be escaped '\'

axlCmdRegister("easymg" 'EasyMG ?cmdType "interactive")
unless(boundp('formHandle) formHandle = nil)

inLineForm = '("

	FILE_TYPE=FORM_DEFN VERSION=2
	FORM
	FIXED
	PORT 61 300
	HEADER \"Easy match group generator\"
	
	TILE
	
	FIELD select1
	FLOC 3 1
	MENUBUTTON \"Select Symbol 1\" 15 3
	ENDFIELD
	
	FIELD symb1RefDes
	TLOC 22 1
	STRFILLIN 35 200
	ENDFIELD
	
	FIELD select2
	FLOC 3 4
	MENUBUTTON \"Select Symbol 2\" 15 3
	ENDFIELD
	
	FIELD symb2RefDes
	TLOC 22 4
	STRFILLIN 35 200
	ENDFIELD
	
	TEXT \"Match Group name :\"
	TLOC 3 7
	ENDTEXT
	
	FIELD mgNameFillin
	TLOC 22 7
	STRFILLIN 35 200
	ENDFIELD
	
	FIELD genNetList
	FLOC 3 10
	MENUBUTTON \"Generate common nets list\" 56 3
	ENDFIELD
	
	FIELD netList
	FLOC 3 13
	LIST \"\" 56 10
	OPTIONS multiselect sort
	ENDFIELD
	
	FIELD voltageCheckList
	FLOC 3 33
	CHECKLIST \"Remove nets with VOLTAGE property\"
	ENDFIELD
	
	FIELD selectAllCheckList
	FLOC 40 33
	CHECKLIST \"Select All nets\"
	ENDFIELD
	
	FIELD patternCheckList
	FLOC 3 35
	CHECKLIST \"Only display nets that match this pattern :\"
	ENDFIELD
	
	FIELD patternFillin
	TLOC 3 37
	STRFILLIN 54 100
	ENDFIELD

	FIELD createMG
	FLOC 3 40
	MENUBUTTON \"Create MG\" 10 3
	ENDFIELD
	
	FIELD close
	FLOC 20 40
	MENUBUTTON \"Close\" 10 3
	ENDFIELD
	
	ENDTILE
	ENDFORM
")

logFilePort = nil
symb1 = nil
symb2 = nil

procedure( EasyMG()
let((mRightClickPopup mLogTitle)
	mRightClickPopup = axlUIPopupDefine(nil, list(list("Done" 'axlFinishEnterFun) list("Cancel" 'axlCancelEnterFun)))
	axlUIPopupSet(mRightClickPopup)
	
	; CREATE (OR APPEND) THE LOGFILE
	mLogTitle = strcat("./EasyMG-" axlCurrentDesign() ".log")
	logFilePort = outfile(mLogTitle "a")
	fprintf(logFilePort "*****************************************************************\n")
	fprintf(logFilePort "    EasyMG.il log\n\n")
	fprintf(logFilePort "    Drawing          : %s.brd\n" axlCurrentDesign())
	fprintf(logFilePort "    Software Version : %s\n" getVersion())
	fprintf(logFilePort "    Date/Time        : %s\n" getCurrentTime())
	fprintf(logFilePort "*****************************************************************\n\n")
	drain(logFilePort)
	
	; CREATE AND DISPLAY THE FORM
	fw = axlFormCreate('formHandle list("myform" inLineForm) list("center") 'EasyMGCallback t nil)
	axlFormSetField(fw "mgNameFillin" "MG_")
	axlFormSetField(fw "voltageCheckList" t)
	axlFormSetFieldEditable(fw "symb1RefDes" nil)
	axlFormSetFieldEditable(fw "symb2RefDes" nil)
	axlFormDisplay(fw)	

))

procedure( GetSymbol()
let((mSymb)
	axlSetFindFilter(?enabled list("noall" "symbols") ?onButtons list("noall" "symbols"))
	while( mSymb == nil
		axlSingleSelectPoint()
		mSymb = car(axlGetSelSet())
	) ;while
	printf("%s is selected\n\n" mSymb->component->name)
	axlFormListDeleteAll(fw "netList")
	mSymb
)) ;let,procedure

procedure( EasyMGCallback(fw)
prog((i mNetList1 mNetList2 mFlagExists mCommonNetList mSelectedNets mPattern mMGName mMG mPinPair mExistingMGs mPinList mPin1 mPin2)
	case( fw->curField
		
		("select1"
			printf("\nSelect symbol 1\n")
			symb1 = GetSymbol()
			axlFormSetField(fw "symb1RefDes" symb1->component->name)
		) ;case "select1"
		
		("select2"
			printf("\nSelect symbol 2\n")
			symb2 = GetSymbol()
			axlFormSetField(fw "symb2RefDes" symb2->component->name)
		) ;case "select2"
		
		("genNetList"
			when( symb1 == nil || symb2 == nil
				axlMsgPut('("Please select both symbols before generating the common nets list\n" 3) )
				return()
			) ;when

			; CREATE SYMBOLS' NETS LISTS
			mNetList1 = symb1~>pins~>net
			mNetList2 = symb2~>pins~>net
			
			mFlagExists = 0
			; CREATE LIST OF COMMON NETS
			; get through the nets of the first symbol
			for(i 0 length(mNetList1)-1
				; compare them to each nets of the second symbol
				for(j 0 length(mNetList2)-1
					; if there is a common net ...
					when(nth(i mNetList1) == nth(j mNetList2) 
						; ... we check that it hasn't been registered in mCommonNetList yet
						for(k 0 length(mCommonNetList)-1
							when(mFlagExists == 0
									if(nth(j mNetList2) == nth(k mCommonNetList)
										then mFlagExists = 1
										else mFlagExists = 0
									) ;if
							) ;when
						) ;for
						
						; register the net if it hasn't been
						when(mFlagExists == 0
								mCommonNetList = cons(nth(j mNetList2) mCommonNetList)
								j = length(mNetList2)-1
						) ;when
						
						mFlagExists = 0
					) ;when
				) ;for 2
			) ;for 1
			
			
			; REMOVE NETS WITH "VOLTAGE" PROPERTY IF THE CHECKBOX IS SET
			when(axlFormGetField(fw "voltageCheckList") 
				foreach(net mCommonNetList
					when(assoc('VOLTAGE axlDBGetProperties(net '(user allegro)))
						mCommonNetList = remq(net mCommonNetList)
					) ;when
				) ;foreach
			) ;when
			
			; REMOVE NETS THAT DOESN'T MATCH THE PATTERN IF THE CHECKBOX IS SET
			when(axlFormGetField(fw "patternCheckList") 
			mPattern = upperCase(axlFormGetField(fw "patternFillin"))
				foreach(net mCommonNetList
					unless(rexMatchp(mPattern net->name)
						mCommonNetList = remq(net mCommonNetList)
					);unless
				) ;foreach
			) ;when
			
			; PRINT mCommonNetList TO THE FORM'S LIST FIELD
			axlFormListDeleteAll(fw "netList")
			;foreach(net mCommonNetList printf("hi %s\n" net))
			foreach(net mCommonNetList 
				axlFormSetField(fw "netList" net->name)
			) ;foreach
			axlFormSetField(fw "netList" nil) ; required to display the list	
			
			; SELECT ALL NETS IF THE CORRESPONDING CHECKLIST IS SET
			when(axlFormGetField(fw "selectAllCheckList") 
				axlFormListSelAll(fw "netList" t)
			) ; when
		) ;case "genNetList"
		
		("selectAllCheckList"
			if(axlFormGetField(fw "selectAllCheckList") 
				then
					axlFormListSelAll(fw "netList" t)
				else
					axlFormListSelAll(fw "netList" nil)
			) ; if
		) ;case "selectAllCheckList"
		
		("createMG"
			mMGName = axlFormGetField(fw "mgNameFillin")
			; CHECKS THAT THE CHOSEN MG NAME ISN'T ALREADY USED
			mExistingMGs = axlDBGetDesign()->matchgroup
			foreach(mg mExistingMGs
				when(mg->name == mMGName
					axlMsgPut('("The MG name you entered is already used, please choose another name\n" 3) )
					return()
				) ;when
			) ;foreach
			
			mMG = axlMatchGroupCreate(mMGName)
			mSelectedNets = axlFormListGetSelItems(fw "netList")
			
			when( length(mSelectedNets) < 2
				axlMsgPut('("You must select at least two nets before creating a Match Group\n" 3) )
				return()
			) ;when
			
			; CREATE PIN PAIRS AND ADD THEM TO THE MATCH GROUP
			i = 1
			foreach(net mSelectedNets
				mPinList = axlPinsOfNet(net 'pins)
				foreach(pin mPinList
					if(pin->parent == symb1 mPin1 = pin)		
					if(pin->parent == symb2 mPin2 = pin)
				) ;foreach
				;printf("%d  -  %s  -  %s  -  net : %s\n" i strcat(symb1->component->name "." mPin1->number) strcat(symb2->component->name "." mPin2->number) net)
				fprintf(logFilePort "%d  -  %s  -  %s  -  net : %s\n" i strcat(symb1->component->name "." mPin1->number) strcat(symb2->component->name "." mPin2->number) net)
				mPinPair = axlPinPair(mPin1 mPin2)
				
				unless(axlMatchGroupAdd(mMG  mPinPair)
					axlMsgPut('("Something went wrong while trying to add a pin pair to the Match Group : %s %s\n" 3) mPin1->name mPin2->name)
					return()
				) ;unless
				
				;axlDBAddProp(list(mMG) list("RELATIVE_PROPAGATION_DELAY" list(list(mMG strcat(mMG->name ":G:::100 ns:5 %")))))
				;(mMG mPinPair strcat(mMG->name ":G:::100 ns:5 %"))
				
				i++
			) ;foreach
			
			fprintf(logFilePort "\nMatch Group \"%s\" created.\n\n" mMGName)
			printf("%s has been created" mMGName)
			axlFormSetField(fw "symb1RefDes" "")
			axlFormSetField(fw "symb2RefDes" "")
			drain(logFilePort)
			axlShell("done")
		) ;case "createMG"
		
		( "close"
			fprintf(logFilePort "EasyMG closed.\n\n")
			printf("EasyMG closed.")
			axlClearSelSet()
			close(logFilePort)
			axlFormClose(fw)
			axlShell("done")
			
		) ;case "close"
	) ;case

))

;EasyMG()