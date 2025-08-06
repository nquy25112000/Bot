#ifndef __BIAS_DATA_BY_TYPE_MQH__
#define __BIAS_DATA_BY_TYPE_MQH__


void clearData() {
   ArrayFree(negTicketList);
   ArrayFree(posTicketList);
   ArrayFree(frozTicketList);
   ArrayFree(targetCentList);
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

int getBiasOrderTypeByHour(int hour){
   if(hour == 0) { // nếu 0h thì nó sẽ scan qua signal của D1 H4 H1 luôn bằng đệ quy
      return getBiasOrderType(BIAS_TF_D1);
   } else if (hour == 4){ // nếu 4h thì nó sẽ scan qua signal của H4 trước, nếu k có thì nó scan qua H1 bằng đệ quy
      return getBiasOrderType(BIAS_TF_H4);
   } else { // các hour còn lại gồm 1 2 3 5 6 7 thì nó gọi H1
      return getBiasOrderType(BIAS_TF_H1);
   }
}


// Phải viết trả về int thì mới hoạt động được vì ENUM_ORDER_TYPE là kiểu hằng số int, 0 là buy 1 là sell. vậy none sẽ là -1
int getBiasOrderType(BiasTF timeFrameRequest) {

   BiasConfig cfg;
   cfg.symbol = _Symbol;
   cfg.timeframe = timeFrameRequest;
   BiasResult biasResult;
   biasResult = DetectBias(cfg);
   if (biasResult.type == "SELL") {
      setDataByTimeFrame(timeFrameRequest);
      isRunningBIAS = true;
      return 1;
   }
   else if (biasResult.type == "BUY") {
      setDataByTimeFrame(timeFrameRequest);
      isRunningBIAS = true;
      return 0;
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
   return -1;
}

void setDataByTimeFrame(BiasTF timeFrameRequest){
   isRunningBIAS = true;
   if(timeFrameRequest == BIAS_TF_D1){
      dcaPositiveVol = 0.1;
      biasType = DAILY_BIAS;
      maxProfit = 900;
   } else if(timeFrameRequest == BIAS_TF_H4){
      dcaPositiveVol = 0.08;
      biasType = H4_BIAS;
      maxProfit = 600;
   } else if(timeFrameRequest == BIAS_TF_H1){
      dcaPositiveVol = 0.06;
      biasType = H1_BIAS;
      maxProfit = 300;
   }
}

void initTargetCentList(){
   ArrayResize(targetCentList, 3);
   if (biasType == DAILY_BIAS) {
      ArrayCopy(targetCentList, targetCentD1List);
   }
   else if (biasType == H4_BIAS) {
      ArrayCopy(targetCentList, targetCentH4List);
   }
   else if (biasType == H1_BIAS) {
      ArrayCopy(targetCentList, targetCentH1List);
   }
}

#endif // __BIAS_DATA_BY_TYPE_MQH__