#ifndef __BIAS_DATA_BY_TYPE_MQH__
#define __BIAS_DATA_BY_TYPE_MQH__


// lấy mảng theo loại âm dương hoặc frozen theo loại
void getBiasArray(string biasType, string arrayType, TicketInfo &result[]) {
   if (biasType == DAILY_BIAS) {
      getArrayByType(arrayType, dailyBiasPositive, dailyBiasNegative, dailyBiasFrozen, result);
   } else if (biasType == H4_BIAS) {
      getArrayByType(arrayType, h4BiasPositive, h4BiasNegative, h4BiasFrozen, result);
   } else if (biasType == H1_BIAS) {
      getArrayByType(arrayType, h1BiasPositive, h1BiasNegative, h1BiasFrozen, result);
   }
}

void getArrayByType(string arrayType,
                     TicketInfo &positive[],
                     TicketInfo &negative[],
                     TicketInfo &frozen[],
                     TicketInfo &result[]) {

      if (arrayType == POSITIVE_ARRAY)
         copyTicketArray(positive, result);
      else if (arrayType == NEGATIVE_ARRAY)
         copyTicketArray(negative, result);
      else if (arrayType == FROZEN_ARRAY)
         copyTicketArray(frozen, result);
      else
         ArrayFree(result);
}

void updateBiasArray(string biasType, string arrayType, TicketInfo &result[]) {
   if (biasType == DAILY_BIAS) {
      updateArrayByType(arrayType, dailyBiasPositive, dailyBiasNegative, dailyBiasFrozen, result);
   } else if (biasType == H4_BIAS) {
      updateArrayByType(arrayType, h4BiasPositive, h4BiasNegative, h4BiasFrozen, result);
   } else if (biasType == H1_BIAS) {
      updateArrayByType(arrayType, h1BiasPositive, h1BiasNegative, h1BiasFrozen, result);
   }
}

void updateArrayByType(string arrayType,
                     TicketInfo &positive[],
                     TicketInfo &negative[],
                     TicketInfo &frozen[],
                     TicketInfo &result[]) {
      if (arrayType == POSITIVE_ARRAY)
         copyTicketArray(result, positive);
      else if (arrayType == NEGATIVE_ARRAY)
         copyTicketArray(result, negative);
      else if (arrayType == FROZEN_ARRAY)
         copyTicketArray(result, frozen);
}

void copyTicketArray(TicketInfo &source[], TicketInfo &destination[]) {
   int size = ArraySize(source);
   ArrayResize(destination, size);
   for (int i = 0; i < size; i++) {
      destination[i] = source[i];
   }
}

void updateDailyBiasArray(string arrayType, TicketInfo &result[]){
      if (arrayType == POSITIVE_ARRAY)
         copyTicketArray(dailyBiasPositive, result);
      else if (arrayType == NEGATIVE_ARRAY)
         copyTicketArray(dailyBiasNegative, result);
      else if (arrayType == FROZEN_ARRAY)
         copyTicketArray(dailyBiasFrozen, result);
}


void clearDataByType(string biasType) {
   if (biasType == DAILY_BIAS) {
      ArrayFree(dailyBiasNegative);
      ArrayFree(dailyBiasPositive);
      ArrayFree(dailyBiasFrozen);
   }
   else if (biasType == H4_BIAS) {
      ArrayFree(h4BiasNegative);
      ArrayFree(h4BiasPositive);
      ArrayFree(h4BiasFrozen);
   }
   else if (biasType == H1_BIAS) {
      ArrayFree(h1BiasNegative);
      ArrayFree(h1BiasPositive);
      ArrayFree(h1BiasFrozen);
   }
}

// thêm phần tử vào mảng các mảng theo loại để xác định ticket nào thuộc loại nào
void AddTicketIdByType(string biasType, ulong ticketId) {
   if (biasType == DAILY_BIAS) {
      AddTicketIdToArray(dailyBiasTicketIds, ticketId);
   } else if (biasType == H4_BIAS) {
      AddTicketIdToArray(h4BiasTicketIds, ticketId);
   } else if (biasType == H1_BIAS) {
      AddTicketIdToArray(h1BiasTicketIds, ticketId);
   }
}

// Thêm phần tử vào mảng
void AddTicketIdToArray(ulong &arr[], ulong value) {
  int size = ArraySize(arr);
  ArrayResize(arr, size + 1);
  arr[size] = value;
}

// lấy danh sách volume negative theo type
void GetVolumeNegativeByType(string biasType, double &destination[]){
   if (biasType == DAILY_BIAS) {
      ArrayCopy(destination, dailyBiasNegativeVolume);
   } else if (biasType == H4_BIAS) {
      ArrayCopy(destination, dailyBiasNegativeVolume); // cần viết lại mảng negative volume cho H4
   } else if (biasType == H1_BIAS) {
      ArrayCopy(destination, dailyBiasNegativeVolume); // cần viết lại mảng negative volume cho H1
   }
}

void setFirstEntryByBiasType(string biasType, double firstEntry){
   if (biasType == DAILY_BIAS) {
      priceFirstEntryDailyBias = firstEntry;
   } else if (biasType == H4_BIAS) {
      priceFirstEntryDailyBias = firstEntry; // cần viết lại firstEntry cho H4
   } else if (biasType == H1_BIAS) {
      priceFirstEntryDailyBias = firstEntry; // cần viết lại firstEntry cho H1
   }
}



ENUM_ORDER_TYPE getBiasOrderType(string biasType){

    BiasConfig cfg;
    cfg.symbol = _Symbol;
    cfg.timeframe = biasType == DAILY_BIAS ? BIAS_TF_D1 : (biasType == H4_BIAS ? BIAS_TF_H4 : BIAS_TF_H1);
   BiasResult biasResult = DetectBias(cfg);
   if (biasResult.type == "SELL"){
     return ORDER_TYPE_SELL;
   } else if (biasResult.type == "BUY") {
      return ORDER_TYPE_BUY;
   } else {
     return "NONE";
   }
}


double getPriceFirstEntryByBiasType(string biasType){
   if (biasType == DAILY_BIAS) {
      return priceFirstEntryDailyBias;
   } else if (biasType == H4_BIAS) {
      return priceFirstEntryh4Bias;
   } else if (biasType == H1_BIAS) {
      return priceFirstEntryh1Bias;
   }
   return 0;
}

string getBiasTypeByTicketId(ulong ticketId){
   for(uint i = 0; i < dailyBiasTicketIds.Size(); i++){
      if(ticketId == dailyBiasTicketIds[i]){
         return DAILY_BIAS;
      }
   }
   for(uint i = 0; i < h4BiasTicketIds.Size(); i++){
      if(ticketId == h4BiasTicketIds[i]){
         return H4_BIAS;
      }
   }
   for(uint i = 0; i < h1BiasTicketIds.Size(); i++){
      if(ticketId == h1BiasTicketIds[i]){
         return H1_BIAS;
      }
   }
   return NULL;
}

#endif __BIAS_DATA_BY_TYPE_MQH__