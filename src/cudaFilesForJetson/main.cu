//
// File: main.cu
//
// GPU Coder version                    : 1.4
// CUDA/C/C++ source code generated on  : 07-Aug-2019 18:01:58
//

//***********************************************************************
// This automatically generated example CUDA main file shows how to call
// entry-point functions that MATLAB Coder generated. You must customize
// this file for your application. Do not modify this file directly.
// Instead, make a copy of this file, modify it, and integrate it into
// your development environment.
//
// This file initializes entry-point function arguments to a default
// size and value before calling the entry-point functions. It does
// not store or use any values returned from the entry-point functions.
// If necessary, it does pre-allocate memory for returned values.
// You can use this file as a starting point for a main function that
// you can deploy in your application.
//
// After you copy the file, and before you deploy it, you must make the
// following changes:
// * For variable-size function arguments, change the example sizes to
// the sizes that your application requires.
// * Change the example values of function arguments to the values that
// your application requires.
// * If the entry-point functions return values, store these values or
// otherwise use them as required by your application.
//
//***********************************************************************

// Include Files
#include "main.h"
#include <string.h>
#include <iostream>
#include "faceGenderAgeEmotionDetectionOnJetson.h"
#include "faceGenderAgeEmotionDetectionOnJetson_initialize.h"
#include "faceGenderAgeEmotionDetectionOnJetson_terminate.h"

// Function Declarations
static int main_faceGenderAgeEmotionDetectionOnJetson();

//
// Arguments    : void
// Return Type  : void
//
static int main_faceGenderAgeEmotionDetectionOnJetson(int32_T argc, const char * const argv[])
{
  // Initialize function 'faceGenderAgeEmotionDetectionOnJetson' input arguments.
  // Call the entry-point 'faceGenderAgeEmotionDetectionOnJetson'.
  
  bool bAge = false;
  bool bEmotion = false;
  bool bGender = false;
  
  switch(argc) {
    case 1: break;
    case 2: bGender = !bool(strcmp(argv[1],"true"));
            break;
    case 3: bGender = !bool(strcmp(argv[1],"true"));
            bAge = !bool(strcmp(argv[2],"true"));
            break;
    case 4: bGender = !bool(strcmp(argv[1],"true"));
            bAge = !bool(strcmp(argv[2],"true"));
            bEmotion = !bool(strcmp(argv[3],"true"));
            break;
    default: // Tell the user how to run the program
            std::cerr << "Usage: " << argv[0] << " boolean_Age boolean_Gender boolean_Emotion" <<std::endl<< "e.g.: "<< argv[0] << " true false false" << std::endl;
            return 1;
  }
  
  faceGenderAgeEmotionDetectionOnJetson(bGender, bAge, bEmotion);
}

//
// Arguments    : int32_T argc
//                const char * const argv[]
// Return Type  : int32_T
//
int32_T main(int32_T argc, const char * const argv[])
{
  // Initialize the application.
  // You do not need to do this more than one time.
  faceGenderAgeEmotionDetectionOnJetson_initialize();
  
  // Invoke the entry-point functions.
  // You can call entry-point functions multiple times.
  main_faceGenderAgeEmotionDetectionOnJetson(argc, argv);
  
  // Terminate the application.
  // You do not need to do this more than one time.
  faceGenderAgeEmotionDetectionOnJetson_terminate();
  return 0;
}

//
// File trailer for main.cu
//
// [EOF]
//
