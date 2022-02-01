class ReadChapterType {

  List<String> currentChapter = [];
  List<String> foundNextChapter = [];

  //This is use to store book type
  //It maybe shaped like a document
  int currentPart = 0;
  int currentChapter = 0;



  bool partLabelUsed = false;

  List<String> currentPartLabel = [];

  List<String> currentTopLine = '';
  String currentBottomLine = '';


  //Starting position on page of the header start int (0-3)
  int atCreatedBookLine = 0;





  ///////////////////////////////////////
  /// All headers start with Capital

  //TOP LINE Options
  bool topNumberOnly = false;
  bool topChapterEngNumber = false;
  bool topChapterNumber = false;
  bool topCapitalNameOnly = false;
  bool topNumberCapitalName = false;


  // BOTTOM LINE
  bool bottomEmpty = false;
  bool bottomNameOnly = false;
  bool bottomCapitalName = false;
  
  
  
  
  
  /////////////////////////////////////////////////////
  
  
  
  ReadChapterType.empty() {
    
    currentPart = 0;
    currentChapter= 0;
    partLabelUsed = false;
    
    currentPartLabel = '';
    currentTopLine = '';
    currentBottomLine = '';
    
    
  }
  
  
  
  
  bool anyTopTrue() {
    if (topNumberOnly) return true;
    if (topChapterEngNumber) return true;
    if (topChapterNumber) return true;
    if (topCapitalNameOnly) return true;
    if (topNumberCapitalName) return true;
    return false;
  }




  bool anyBottomTrue() {
    if (bottomEmpty) return true;
    if (bottomNameOnly) return true;
    if (bottomCapitalName) return true;
    return false;
  }




}