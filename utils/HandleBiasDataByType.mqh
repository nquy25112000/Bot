#ifndef __BIAS_DATA_BY_TYPE_MQH__
#define __BIAS_DATA_BY_TYPE_MQH__


void clearData() {
   ArrayFree(negTicketList);
   ArrayFree(posTicketList);
   ArrayFree(frozTicketList);
   negativeTicketIndex = 0;
}

// lấy danh sách volume negative theo type
void GetVolumeNegativeByType(double& destination[]) {
   if (biasType == DAILY_BIAS) {
      ArrayCopy(destination, negD1volumes);
   }
   else if (biasType == H4_BIAS) {
      ArrayCopy(destination, negH4volumes);
   }
   else if (biasType == H1_BIAS) {
      ArrayCopy(destination, negH1volumes);
   }
}

ENUM_ORDER_TYPE getBiasOrderType(BiasTF timeFrameRequest) {

   BiasConfig cfg;
   cfg.symbol = _Symbol;
   cfg.timeframe = timeFrameRequest;
   BiasResult biasResult;
   biasResult = DetectBias(cfg);
   if (biasResult.type == "SELL") {
      setDataByTimeFrame(timeFrameRequest);
      isRunningBIAS = true;
      return ORDER_TYPE_SELL;
   }
   else if (biasResult.type == "BUY") {
      setDataByTimeFrame(timeFrameRequest);
      isRunningBIAS = true;
      return ORDER_TYPE_BUY;
   }
   else {
      if (timeFrameRequest == BIAS_TF_D1)
      {
         getBiasOrderType(BIAS_TF_H4);
      }
      else if (timeFrameRequest == BIAS_TF_H4)
      {
         getBiasOrderType(BIAS_TF_H1);
      }
   }
   return NULL;
}

void setDataByTimeFrame(BiasTF timeFrameRequest){
   isRunningBIAS = true;
   if(timeFrameRequest == BIAS_TF_D1){
      dcaPositiveVol = 0.1;
      biasType = DAILY_BIAS;
   } else if(timeFrameRequest == BIAS_TF_H4){
      dcaPositiveVol = 0.08;
      biasType = H4_BIAS;
   } else if(timeFrameRequest == BIAS_TF_H1){
      dcaPositiveVol = 0.06;
      biasType = H1_BIAS;
   }
}


// Hàm để test như cũ
ENUM_ORDER_TYPE getOrder(){
   BiasConfig cfg;
   cfg.symbol = _Symbol;
   cfg.timeframe = BIAS_TF_D1;
   BiasResult biasResult;
   biasResult = DetectBias(cfg);
   if (biasResult.type == "SELL") {
      setDataByTimeFrame(BIAS_TF_D1);
      return ORDER_TYPE_SELL;
   }
   setDataByTimeFrame(BIAS_TF_D1);
   return ORDER_TYPE_BUY;
 }


#endif // __BIAS_DATA_BY_TYPE_MQH__