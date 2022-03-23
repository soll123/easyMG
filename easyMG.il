; skill load "easyMG.il"
; Form rules:
;	- every non-blank line must have a tab character
;	- any quote must be escaped (e.g. use the backslash '\')
;	- any paraenthesis '()' must be escaped '\'
unless(boundp('formHandle) formHandle = nil)
inLineForm = '("

	FILE_TYPE=FORM_DEFN VERSION=2
	FORM
	FIXED
	PORT 64 200
	HEADER \"Easy match group generator\"
	
	TILE
	
	TEXT \"Match Group name :\"
	TLOC 3 1
	ENDTEXT
	
	FIELD mg_name
	TLOC 23 1
	STRFILLIN 35 200
	ENDFIELD

	FIELD ok
	FLOC 3 4
	MENUBUTTON \"Create MG\" 10 3
	ENDFIELD
	
	FIELD cancel
	FLOC 20 4
	MENUBUTTON \"Cancel\" 10 3
	ENDFIELD
	
	GROUP \"\"
	FLOC 1 6
	FSIZE 0 1
	ENDGROUP

	ENDTILE
	ENDFORM
")

procedure( easyMG()
	rightClickPopup = axlUIPopupDefine(nil, list(list("Done" 'axlFinishEnterFun) list("Cancel" 'axlCancelEnterFun)))
	axlUIPopupSet(rightClickPopup)

	; SELECT SYMBOLS
	printf("\nSelectionnez un premier symbol\n")
	symb1 = getSymbol()
	printf("\nSelectionnez un deuxieme symbol\n")
	symb2 = getSymbol()
	netListCommon = '()
	flagExists = 0

	; CREATE (OR APPEND) THE LOGFILE
	logTitle = strcat("./easyMG-" symb1->component->name "-" symb2->component->name ".log")
	logFilePort = outfile(logTitle "a")
	fprintf(logFilePort "*****************************************************************\n\n")
	fprintf(logFilePort "    createPinPair.il log\n\n")
	fprintf(logFilePort "    Drawing          : %s.brd\n" axlCurrentDesign())
	fprintf(logFilePort "    Software Version : %s\n" getVersion())
	fprintf(logFilePort "    Date/Time        : %s\n\n" getCurrentTime())
	fprintf(logFilePort "*****************************************************************\n\n")
	fprintf(logFilePort "Symbol 1 : %s\nSymbol 2 : %s\n\n" symb1->component->name symb2->component->name)
	drain(logFilePort)

	; CREATE SYMBOLS' NETS LISTS
	mNetList1 = symb1~>pins~>net
	mNetList2 = symb2~>pins~>net
	netListCommon = nil

	; CREATE LIST OF COMMON NETS
	; get through the nets of the first symbol
	for(i 0 length(mNetList1)-1
		; compare them to each nets of the second symbol
		for(j 0 length(mNetList2)-1
			; if there is a common net ...
			if(nth(i mNetList1) == nth(j mNetList2) then
				; ... we check that it hasn't been registered in netListCommon yet
				for(k 0 length(netListCommon)-1
					if(flagExists == 0
						then
							if(nth(j mNetList2) == nth(k netListCommon)
								then flagExists = 1
								else flagExists = 0
							) ;if
					) ;if
				) ;for
				
				; register the net if it hasn't been
				if(flagExists == 0
					then
						netListCommon = cons(nth(j mNetList2) netListCommon)
						j = length(mNetList2)-1
				) ;if
				
				flagExists = 0
			) ;if
		) ;for 2
	) ;for 1

	; REMOVE NETS WITH "VOLTAGE" PROPERTY FROM COMMON NETS LIST
	foreach(net netListCommon
		if(assoc('VOLTAGE axlDBGetProperties(net '(user allegro))) != nil
		then
			remd(net netListCommon)
		) ;if
	) ;foreach

	mgName = ""
	fw = axlFormCreate('formHandle list("myform" inLineForm) list("center") 'easyMGCallback t nil)
	axlFormSetField(fw "mg_name" "MG_")
	axlFormSetField(fw "symb1_list" "MG_")
	axlFormDisplay(fw)	
		
)

procedure( getSymbol()
let((mSymb)
	axlSetFindFilter(?enabled list("noall" "symbols") ?onButtons list("noall" "symbols"))
	while( mSymb == nil
		axlSingleSelectPoint()
		mSymb = car(axlGetSelSet())
	) ;while
	mSymb
)) ;let,procedure

procedure( easyMGCallback(fw)
prog((mPinList mPin1 mPin2)
	if(fw->curField == "ok" then
		mgName = axlFormGetField(fw "mg_name")
		
		; CREATE MATCH GROUP AND PIN PAIR
		mg = axlMatchGroupCreate(mgName)
		i = 1
		foreach(net netListCommon
			mPinList = axlPinsOfNet(net 'pins)
			foreach(pin mPinList
				if(pin->parent == symb1 mPin1 = pin)		
				if(pin->parent == symb2 mPin2 = pin)
			) ;foreach
			printf("%d   -   %s   -   %s   -   net : %s\n" i strcat(symb1->component->name "." mPin1->number) strcat(symb2->component->name "." mPin2->number) net->name)
			fprintf(logFilePort "%d   -   %s   -   %s   -   net : %s\n" i strcat(symb1->component->name "." mPin1->number) strcat(symb2->component->name "." mPin2->number) net->name)
			axlMatchGroupAdd(mg  axlPinPair(mPin1 mPin2))
			i++
		) ;foreach
		
		fprintf(logFilePort "\nMatch Group \"%s\" created.\n\n" mgName)
		printf("Match Group \"%s\" created.\n\n" mgName)
		
		close(logFilePort)
		axlFormClose(fw)
	) ;if
	
	if(fw->curField == "cancel" then
		fprintf(logFilePort "easyMG canceled.")
		printf("easyMG canceled.")
		close(logFilePort)
		axlFormClose(fw)
	) ;if

))

; procedure(myCancel()
; let (()
	; axlCancelEnterFun()
; )) ;let,procedure



easyMG()