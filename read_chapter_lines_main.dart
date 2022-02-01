import 'package:flutter_laureen/allankcode/paragraphs/paragraph_lines.dart';
import 'package:flutter_laureen/allankcode/string_lines/line_util.dart';
import 'package:flutter_laureen/allankcode/string_lines/tidy_line.dart';
import 'package:flutter_laureen/allankcode/string_lines/words_to_line.dart';
import 'package:flutter_laureen/allankcode/string_words/line_to_words.dart';
import 'package:flutter_laureen/allankcode/string_words/string_numbers.dart';
import 'package:flutter_laureen/allankcode/string_words/words_compare.dart';
import 'package:flutter_laureen/data_book/model/a_paragraph.dart';
import 'package:flutter_laureen/data_book/model/app_data.dart';
import 'package:flutter_laureen/data_processing_book/db/ra_database_helper.dart';
import 'package:flutter_laureen/new_book_processing/examine_chapter_no_contents.dart';
import 'package:flutter_laureen/new_book_processing/read_chapter_type.dart';
import 'package:flutter_laureen/data_scan_book/db/other_words_create.dart';
import 'package:flutter_laureen/data_processing_book/model/raitem.dart';
import 'package:flutter_laureen/new_book_processing/create_chapter_type.dart';
import 'package:flutter_laureen/new_book_processing/paragraph_details.dart';
import 'package:flutter_laureen/new_book_processing/paragraph_production.dart';
import 'package:flutter_laureen/word_net/word_types_lists.dart';

class ReadChapterLinesMain {

 
  Book _book = Book.empty();
  ReadChapterType _readChapterType = ReadChapterType.empty();

  Map _otherWordsMap = Map();
  Map get getOtherWordsMap => _otherWordsMap;


  int _lawOfOneBookNumber = -1;
  int _lawOfOneSessionNumber = 0;


  int _atParagraphNumber = 0;
  int get getAtParagraphNumber => _atParagraphNumber;

  List<AParagraph> _paragraphs = [];

  String _chapterTimeSeconds = '';
  String get getChapterTimeSeconds => _chapterTimeSeconds;

  int _atPage = 0;
  int get getPageNo => _atPage;

  int _atChapter = 0;
  List<String> _contentsNamesFound = [];
  
  int _processedChapterSize = 0;

  late WordTypeLists _wordTypeLists;

  List<String> _bookLines = [];

  int _atLineNo = 0;
  int get getBookLine => _atLineNo;

  bool _bookNameInChapters = false;

  bool _creatingChapterNamesHere = false;

  String _errorMessage = '';
  String get getErrorMessage => _errorMessage;







  ////////////////////////////////////////////////////////////////////////////
  ///   INIT CHAPTER MAKING HERE
  ///

  //RETURN TRUE IF BOOK I AM RA
  Future initChapterMaking(List<String> bookLines, int bookNumber, String bookName, ReadChapterType readChapterType,
      WordTypeLists wordTypeLists, Map otherWordsMap, List<String> chapterNames, List<String> chapterNamesOnly) async {

    print('  ');
    print('############################################################################');
    print('        INIT CHAPTER MAKING....................');

    _otherWordsMap = otherWordsMap;
    _chapterNames = chapterNames;
    _bookLines = bookLines;
    _wordTypeLists = wordTypeLists;
    _bookName = bookName;
    _readChapterType = readChapterType;
    _bookNameWords = LineToWords.getWordsFromLine(bookName);
    _bookNumber = bookNumber;

    if (_readChapterType.noContents) {
      if (_readChapterType.noContentsStartWord.isNotEmpty) {
        _currentChapterName = _readChapterType.noContentsStartWord;
        _creatingChapterNamesHere = true;
      }
    }
    
    if (WordsCompare.containsIgnoreCase(bookName, 'The Law of One')) {
      _lawOfOneBookNumber = RaDatabaseHelper().findRaBookNumber(bookName);
      print('>>>>>>>>>>>>>>>>>>>');
      print('>>>>>>>>>>>>>>>>>>> FOUND LAW OF ONE BOOK: '+_lawOfOneBookNumber.toString());
      print('>>>>>>>>>>>>>>>>>>>');
    }

    print('  ');
    return;
  }






  // EXIT TRUE IF CARRY ON, FALSE IF STOP
  Future<bool> startMakingChapter(int startLineNo, AppData appData, int atChapterNo, int atParagraphNumber,
      bool bookNameInChapters, int allRaItemsSize) async {

    _atLineNo = startLineNo;
    if (_atLineNo >= _bookLines.length) return true;
    if (_bookLines.isEmpty) {
      _errorMessage = 'NO BOOK LINES OR PAGES TO READ!!!!!!!!!!!!';
      return await finalProcess(DateTime.now(), false);
    }

    _bookNameInChapters = bookNameInChapters;
    _allRaItemsSize = allRaItemsSize;
    _atChapter = atChapterNo;
    _atParagraphNumber = atParagraphNumber;

    print('  ');
    print('################################# START SCANNING BOOK TEXT LINES #################################');
    print('--- AT PARAGRAPH ID: '+_atParagraphNumber.toString());
    print('--- AT LINE NO: '+ _atLineNo.toString()+' / '+_bookLines.length.toString());
    print('--- AT CHAPTER: '+_atChapter.toString()+ ' / '+_chapterNames.length.toString());
    print('--- AT PAGE: '+_atPage.toString());
    DateTime dateFirst = DateTime.now();
    print('--- Start Time: ' + dateFirst.toString());
    

    // IF LAW OF ONE...
    //If new chapter get new book session
    if (_lawOfOneBookNumber > 0) {
      _lawOfOneSessionNumber = RaDatabaseHelper().findRaSession(_currentChapterName);
    }

    if (!_readChapterType.noContents) {
      print('--- START LOOKING FOR CHAPTER AND BUILD: ' + _chapterNames[_atChapter].toString());
    }
    //ANY SPECIAL OPTIONS HERE
    //1. searchByCapitalName
    
    String paragraphString = ''; //ALL SENTENTCES STORED UNTIL PARAGRAHPH END
    //String paragraphHeading = chapterNamesOnly[_atChapter];
    
    int emptyLinesCount = 0;
    int lastEmptyLinesCount = 0;

    for (int i = startLineNo; i < _bookLines.length; i++) {
      String bookLineCheck = _bookLines[i].trim();
      
      // NO CHAPTERS check for NEW CONTENTS LABEL
      if (_creatingChapterNamesHere) {
        List<String> lineWords = LineToWords.removeRubbishWordsLabel(bookLineCheck);

        //Check for empty line tally
        bool lineEmpty = LineUtil.lineEmptyOrReturn(lineWords);
        if (lineEmpty) {
          emptyLinesCount ++;
        } else {
          lastEmptyLinesCount = emptyLinesCount;
          emptyLinesCount = 0;
        }

        if (!lineEmpty) {
          bool chapterExit = await _noContentsFoundChapterExit(appData, bookLineCheck, lineWords,
              lastEmptyLinesCount, i);
          if (chapterExit) return await finalProcess(dateFirst, true);
          paragraphString = await _createParagraphBegin(bookLineCheck, paragraphString);
        }
      }

      //READ_CHAPTERS  check for NEW CONTENTS LABEL
      if (!_creatingChapterNamesHere) {
        if (_atChapter < _chapterNames.length) {
          //GET NEXT LINE
          //Looks easy enough except i need to next page start if at end of this page!!!
          String nextLine = '';
          if (i < _bookLines.length - 1) {
            nextLine = _bookLines[i + 1].trim();
          }

          String foundChapterHeader = await _foundChapter(bookLineCheck, nextLine);
          if (foundChapterHeader.isNotEmpty) {    //FOUND START OF CHAPTER
            if (WordsCompare.equalsIgnoreCase(foundChapterHeader, 'ERROR  ERROR')) {
              _errorMessage = '!!! NO CHAPTER TYPE FOUND !!!!!';
              print('!!!!!!!!!!!!!!!!!! NO CHAPTER TYPE FOUND !!!!!!!!!!!!!!!!!');
              return await finalProcess(dateFirst, false);   /// ERROR !!!!
            }
            if (foundChapterHeader != '##########') {
              int carryOn = await _foundNextChapterReadTypeOnly(appData, foundChapterHeader);
              if (carryOn == -9999) {
                _errorMessage = '!!! SOME ERROR HAS OCCURED !!!';
                return await finalProcess(dateFirst, false); //ERROR!!!!
              }
              if (carryOn == 1) {
                return await finalProcess(dateFirst, true);
              }
            }
          }

          paragraphString = await _createParagraphBegin(bookLineCheck, paragraphString);
        }
      }
      
      _atLineNo = i;
    }

    //Save Last Chapter at end
    if (_paragraphs.isNotEmpty) {
      bool result = await _checkPreviousChapterToProcess(appData);
      if (!result) return await finalProcess(dateFirst, true);                            //ERROR WITH PROCESS!!!
    }
    print('###################################################################################################');
    print('************************* END MAKING PARAGRAPHS FOR BOOK ******************************************');
    print('  ');
    print('--- CREATED CHAPTER: ' + _currentChapterName);
    print('--- Paragraphs: ' + _paragraphs.length.toString());
    print('--- PROCESSED CHAPTERS: ' + _processedChapterSize.toString());
    print('--- CHAPTERS SIZE: ' + _chapterNames.length.toString());
    print('--- AT LINE: '+ _atLineNo.toString()+' / '+_bookLines.length.toString());

    //CHECK FOR SIZES FIRST
    if (_readChapterType.noContentsStartWord.isEmpty) {
      if (_processedChapterSize < _chapterNames.length - 1) {
        print('#####  AT END OF READING. FOUND PROBLEM WITH CHAPTER SIZE AND PROCESSED CHAPTERS');
        return await finalProcess(dateFirst, false);
      }
      return await finalProcess(dateFirst, false);
    }

    return await finalProcess(dateFirst, false);
  }









  Future<bool> finalProcess(DateTime dateFirst, bool foundError) async {
    DateTime dateLast = DateTime.now();
    print('--- Finish Time: ' + dateLast.toString());
    Duration dateDifference = dateLast.difference(dateFirst);
    String durationString = dateDifference.inSeconds.toString();
    print('--- Processed Chapter in seconds: '+ durationString+ ' seconds');
    print('  ');
    print(' ');
    print('   ');
    _chapterTimeSeconds = durationString;
    if (foundError) return false;
    if (_atLineNo == -9999) return false;
    return false;
  }





  








  ///////////////////////////////////////////////////////////////////////////
  ///
  /// CREATE A PARAGRAPH HERE FROM THE LINE FOUND
  ///
  
  Future<String> _createParagraphBegin(String tidyLine, String paragraphString) async {
    if (tidyLine.isNotEmpty) {
      String newLine = tidyLine;
      bool useLine = true;
      List<String> words = LineToWords.getWordsFromLine(tidyLine);
      if (words.length == 1) {

        //todo KEEP EYE ON THIS> MAY NEED THE NUMBER SOME TIME
        //CHECK FOR NUMBER ONLY. IF SO DONT USE
        bool numberOnly = StringNumbers.isValidInt(tidyLine);
        if (numberOnly) useLine = false;
      }

      //IF NUMBER AT END OF LONGER LINE REMOVE NUMBER
      if (words.length > 4) {
        String lastWord = words.last;
        bool numberOnly = StringNumbers.isValidInt(lastWord);
        if (numberOnly) {
          words.removeLast();
          newLine = WordsToLine.createLine(words);
        }
      }

      //CHECK FOR CHAPTER NAME. IF SO DONT USE
      if ((useLine) && (!_creatingChapterNamesHere)) {
        bool currentChapter = await _checkAllChapters(tidyLine);
        if (currentChapter) useLine = false;
      }

      if (useLine) {
        paragraphString += ' ' + newLine;
        bool atEndOfParagraph = await _atEndOfParagraph(tidyLine);
        if (atEndOfParagraph) {
          AParagraph item = await _createParagraph(paragraphString);
          _paragraphs.add(item);
          paragraphString = '';
        }
      }
    }
    return paragraphString;
  }
  
  
  
  
  
  
  Future<bool> _checkAllChapters(String line) async {
    for (String currentChapter in _chapterNames) {
      String currentChapterTidy = TidyLine.removeSymbols(currentChapter);
      String currentLine = TidyLine.removeSymbols(line);
      if (WordsCompare.equalsIgnoreCase(currentLine, currentChapterTidy))
        return true;
    }
    return false;
  }



  Future<bool> _atEndOfParagraph(String tidyLine) async {
    bool endPoint = LineUtil.lineHasEndPoint(tidyLine);
    bool newLine = LineUtil.lineHasReturn(tidyLine);
    if ((endPoint) || (newLine)) {
      return true;
    }
    return false;
  }
  



  Future<AParagraph> _createParagraph(String paragraphString) async {
    String chapter = '';
    if (_creatingChapterNamesHere) {
      chapter = _currentChapterName;
    } else {
      chapter = _chapterNames[_atChapter];
    }
    List<String> completeLines = ParagraphLines().breakParagraphToLines(paragraphString, false, 0);
    AParagraph paragraph = AParagraph(_bookName, '', _bookNumber, chapter, _atChapter, completeLines);
    return paragraph;
  }





  Future<bool> _checkPreviousChapterToProcess(AppData appData) async {
    //PROCESS HERE TO SAVE MEMORY
    if (_currentChapterName.isNotEmpty) {
      bool result = await _processAndSavePreviousChapter(appData);
      if (result) {
        print(' ');
        print('##### > SAVED CHAPTER: ' + _currentChapterName + '  --  PARAGRAPHS: ' + _paragraphs.length.toString());
        _processedChapterSize++;
      }
      return result;
    }
    return false;
  }




  //THIS IS WHERE A WHOLE CHAPTER IS PROCESSED
  Future<bool> _processAndSavePreviousChapter(AppData appData) async {
    ParagraphDetails paragraphDetails = ParagraphDetails(otherWordsSearchItems: []);
    paragraphDetails.atParagraphNumber = _atParagraphNumber;
    RaItem raItem = RaItem(_allRaItemsSize, -1, -1, -1, -1, -1, '', '');

    for (int ii = 0; ii < _paragraphs.length; ii++) {
      bool lastParagraph = false;
      if (ii == (_paragraphs.length-1)) lastParagraph = true;

      AParagraph aParagraph = _paragraphs[ii];

      ParagraphProduction paragraphProduction = ParagraphProduction();
      paragraphDetails.raSessionNo = _lawOfOneSessionNumber;
      paragraphDetails.raBookNo = _lawOfOneBookNumber;
      paragraphDetails = await paragraphProduction.createOneParagraph(appData.allBooks, _wordTypeLists, paragraphDetails,
          aParagraph, lastParagraph, _lawOfOneBookNumber, raItem);

      //RA ITEM ADD
      raItem = paragraphProduction.getRaItem;
      if (raItem.id >= 0) {
        if ((raItem.question.isNotEmpty) || (raItem.response.isNotEmpty)) {
          _chapterRaItems.add(raItem);
          _allRaItemsSize ++;
          raItem = RaItem(_allRaItemsSize, -1, -1, -1, -1, -1, '', '');
        }
      }

      _atParagraphNumber = paragraphDetails.atParagraphNumber; //At paragraph count per chapter
    }

    //SAVE THE LIST OF OTHER WORDS WITH ITS NUMBER
    if (paragraphDetails.otherWordsSearchItems.isNotEmpty) {
      _otherWordsMap = await OtherWordsCreate().addWordsTempList(_otherWordsMap, paragraphDetails.otherWordsSearchItems);
    }
    return true;
  }











  ///##########################################################################
  ///
  ///   READ CHAPTER TYPE SCAN HERE!!!!!!!!!!!!!!!!!!!
  ///
  ///     FOUND CHAPTER HEADER
  ///     todo NEED TO SEPERATE INTO OWN CLASS FILE
  ///     
  ///   RETURN 0 TO CARRY ON
  ///   RETURN 1 TO STOP
  ///   RETURN -9999 ERROR!!!

  Future<int> _foundNextChapterReadTypeOnly(AppData appData, String foundChapterHeader) async {
    //If found first chapter then start paragraphs
    if (WordsCompare.containsIgnoreCase(foundChapterHeader, _chapterNamesOnly.first)) {
      print('FOUND FIRST CHAPTER SO DONT SAVE OR PROCESS YET!!');
      _currentChapterName = foundChapterHeader;
      print('CurrentChapterName: ' + foundChapterHeader);
      return 0; //CARRY ON (ONLY FIRST CHAPTER)
    }
    //REMEMBER!!!: It looks ahead 1 chapter because processing chapter behind
    bool result = await _checkPreviousChapterToProcess(appData);
    if (!result) return -9999; //ERROR
    _currentChapterName = foundChapterHeader;
    return 1; //STOP
  }










  Future<String> _foundChapter(String firstLine, String secondLine) async {
    if (firstLine.trim().isEmpty) return '';

    //IF CHAPTER 0 NEED TO RETURN ITS NAME IF FOUND
    if ((_atChapter == 0) && (_currentChapterName == 'HELLO')) {
      String chapterZero = _chapterNamesOnly[0];
      if (WordsCompare.containsIgnoreCase(firstLine, chapterZero)) {
        print('#########  FOUND VERY FIRST CHAPTER: $_atChapter  ' + _chapterNamesOnly[_atChapter]);
        return chapterZero;
      }
      return '';
    }

    //Check to see its not current chapter
    String currentChapter = TidyLine.removeSymbols(_currentChapterName);
    String firstLineNoSymbols = TidyLine.removeSymbols(firstLine);
    if (WordsCompare.equalsIgnoreCase(firstLineNoSymbols, currentChapter)) return '##########';

    //Check to see if line is similar to book title
    if (!_bookNameInChapters) {
      bool hitResult = WordsCompare.searchWordsInWordsNoOrder(LineToWords.getWordsFromLine(firstLine), _bookNameWords, 2);
      if (hitResult) return '##########';
    }

    //////////////////////////////////////////////////////////////////////////
    //DO QUICK SCAN OF TOP LINE HERE FOR CHAPTER TOP LINE ONLY
    bool haveFoundChapterType = _readChapterType.anyTrue();
    if (haveFoundChapterType) {
      if (_readChapterType.chapterNameNoBottom) {
        return await _topLineChapterNameNoBottom(firstLine, secondLine);
      }
    }

    ///////////////////////////////////////////////////////////////////////
    //NOW LOOK FOR CHAPTER HEADER...
    //If line has 'CHAPTER' in it, get the number only
    if (firstLine.length > 1) {
      firstLine = firstLine.toUpperCase();
      List<String> words = firstLine.split('CHAPTER');
      if (words.length >= 2) {firstLine = 'CHAPTER ' + words[1];
        //print('Split: ' + words.toString() + ' ### Use: ' + firstLine);
      }
    }

    //LINE: Sometimes a number is first, then writing. If so get number only
    //Sometime a number is at top, this can be a page number
    int topLineNumberFound = StringNumbers.removeIntFromWord(firstLine);
    if (topLineNumberFound != -9999) {
      print('   FOUND A NUMBER IN LINE: ' + topLineNumberFound.toString());
    }

    /////////////////////////////////////////////////////////////////////////
    //  FIND CHAPTER TYPE IF NOT FOUND
    if (!haveFoundChapterType) {
      _readChapterType = await CreateChapterType().check(_readChapterType, 0, firstLine, topLineNumberFound, _atChapter, secondLine, _chapterNamesOnly, '');
      haveFoundChapterType = _readChapterType.anyTrue();
    }

    /////////////////////////////////////////////////////////////////////////
    /// SCAN FOR TOP LINE AND BOTTOM LINE
    if (haveFoundChapterType) {
      //REPEAT AGAIN BECAUSE OF CHAPTER TYPE CHECK ABOVE....
      if (_readChapterType.chapterNameNoBottom) {
        return await _topLineChapterNameNoBottom(firstLine, secondLine);
      }

      //RETURN THE CHAPTER FOUND:
      //CHAPTER NO TOP, NAME BOTTOM:
      if (_readChapterType.isTopNumberBottomName()) {
        ///  <<<<------THIS IS A GENERAL CATAGORY

        String testNextChapter = TidyLine.removeSymbols(_chapterNamesOnly[_atChapter + 1]);
        String bottomLineNoSymbols = TidyLine.removeSymbols(secondLine);

        if (_readChapterType.pageNoTopChpNameBottom) {
          //print('   CHECK NEXT CHAPTER: ###' + testNextChapter + '###     with line: ###' + bottomLineNoSymbols);
          if (WordsCompare.containsIgnoreCase(bottomLineNoSymbols, testNextChapter)) {
            //print('   #  FOUND CHAPTER: $_atChapter+1  ' + _chapterNamesOnly[_atChapter + 1]);
            return _chapterNames[_atChapter + 1];
          }
          return '';
        }

        //ALL OTHERS IN THIS CATAGERY
        if (_readChapterType.chpEngNoTopNameBottom) {
          int topEnglishNoFound = StringNumbers.changeEngToNumberLine(firstLine);
          //print('   Page: ' + pageNo.toString() + '   CHECK THIS LINE FOR ENGLISH NUMBER: ' + firstLine);
          //print('                ENGLISH NUMBER: ' + topEnglishNoFound.toString());
          if (topEnglishNoFound == (_atChapter + 1)) {
            //print('   CHECK NEXT CHAPTER: ###' + testNextChapter + '###     with line: ###' + bottomLineNoSymbols);
            if (WordsCompare.containsIgnoreCase(testNextChapter, bottomLineNoSymbols)) {
              //print('   #  FOUND CHAPTER: $_atChapter+1  ' + _chapterNamesOnly[_atChapter + 1]);
              return _chapterNames[_atChapter + 1];
            }
          }
          return '';
        }

        //OTHER FOR NUMBER TYPE
        if (topLineNumberFound == (_atChapter + 1)) {
          //print('   CHECK NEXT CHAPTER: ###' + testNextChapter + '###     with line: ###' + bottomLineNoSymbols);
          if (WordsCompare.containsIgnoreCase(testNextChapter, bottomLineNoSymbols)) {
            //print('   #  FOUND CHAPTER: $_atChapter+1  ' + _chapterNamesOnly[_atChapter + 1]);
            return _chapterNames[_atChapter + 1];
          }
          return '';
        }
      }
    }
    return '';
  }

  












  Future<String> _topLineChapterNameNoBottom(String topLine, String bottomLine) async {
    if ((_atChapter+1) < _chapterNames.length) {
      //CHAPTER NAME TOP
      //NO BOTTOM FIRST (MOST SIMPLE) KEEP SYMBOLS!!!!
      if (bottomLine.trim().isEmpty) {
        String topLineNoSymbols = TidyLine.removeSymbols(topLine).trim();
        String nextChapter = _chapterNames[_atChapter + 1];
        //print('>>>>>>>> CHECK FOR CHAPTER NAME TOP, NO BOTTOM:');
        //print('!!!!!!!  NEED FIND CHAPTER: ' + nextChapter+' --- LINE CHECK: '+topLineNoSymbols);
        if (WordsCompare.equalsIgnoreCase(topLineNoSymbols, nextChapter)) {
          //print('>>>>>> FOUND NEXT CHAPTER IN LINE!!!!!!!!!!!!!!!!!!!!!');
          return nextChapter;
        }
      }
    }
    return '';
  }












  ///#########################################################################
  ///
  /// NO CONTENTS FOUND
  /// If there is a start word then that is first chapter
  /// Go through paragraphs till find another big gap with a possible
  /// chapter name

  /// * There needs to be at least 3 empty gaps above
  ///

  List<String> _stopNoContentsProcess = ['Document Outline'];

  Future<bool> _noContentsFoundChapterExit(AppData appData, String normalLine, List<String> lineWords,
      int lastEmptyLinesCount, int lineNo) async {

    for (String stopLine in _stopNoContentsProcess) {
      if (WordsCompare.containsIgnoreCase(normalLine, stopLine)) {
        print(' ');
        print('>>>  NO CONTENTS HAS FOUND LINE TO STOP READING BOOK  !!!!!!!!!!!!!!!!!!!!');
        print(' * STOP LINE FOUND: '+normalLine);
        print('>>>  AT PAGE: '+_atPage.toString());
        print('>>>  AT LINE: '+ lineNo.toString()+' / '+_bookLines.length.toString());
        print(' ');
        bool result = await _checkPreviousChapterToProcess(appData);
        _atLineNo = _bookLines.length;
        return true;
      }
    }

    String chapterPageNo = await ExamineChapterNoContents().findChapterExit(lineWords,
        lastEmptyLinesCount, _atPage);

    if (chapterPageNo.isNotEmpty) {
      if (chapterPageNo.contains('PAGE')) {
        String pageString = chapterPageNo.replaceAll('PAGE', '').trim();
        int page = StringNumbers.extractIntFromWord(pageString);
        if (page > 0) {
          _atPage = page;
          //print('>>>  AT PAGE: '+_atPage.toString()+'  AT LINE: '+ lineNo.toString());
        }
        return false;
      }

      print('>>>  USE THIS FOR NEXT CHAPTER LABEL  !!!!!!!!!!!!!!!!!!!!');
      print('>>>  WHICH IS: #'+chapterPageNo+'#');
      print('>>>  AT PAGE: '+_atPage.toString());
      print('>>>  AT LINE: '+ lineNo.toString()+' / '+_bookLines.length.toString());
      _chapterNames.add(chapterPageNo);
      _chapterNamesOnly.add(chapterPageNo);

      //FOUND END
      bool result = await _checkPreviousChapterToProcess(appData);
      _currentChapterName = normalLine;
      return true; //STOP
    }
    return false;
  }


  




}

