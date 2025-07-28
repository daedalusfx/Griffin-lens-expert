//+------------------------------------------------------------------+
//|                                        GriffinTickSender.mq5 |
//|                                   Copyright 2025, Griffin Project Team |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Griffin Project Team"
#property version   "3.0" // Version updated for Latency & Glitch Analysis
#property description "Sends tick, slippage, and latency data to the Griffin server."

//--- ورودی‌های قابل تنظیم برای کاربر
input string InpServerUrl = "http://127.0.0.1:5000"; // آدرس پایه سرور پایتون
input int    InpSlippageTestIntervalSeconds = 60;  // هر چند ثانیه یک تست لغزش ارسال شود
input int    InpLatencyTestIntervalSeconds = 30;   // هر چند ثانیه یک تست تأخیر ارسال شود

//--- متغیرهای گلوبال
string broker_name;
string symbol_name;
string tick_server_url;
string slippage_server_url;
string latency_server_url; // جدید: URL برای تست تأخیر

uchar    post_data[];
datetime last_slippage_test_time = 0;
datetime last_latency_test_time = 0; // جدید: زمان آخرین تست تأخیر

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // --- پیکربندی ---
    tick_server_url = InpServerUrl + "/tick";
    slippage_server_url = InpServerUrl + "/slippage_test";
    latency_server_url = InpServerUrl + "/latency_test"; // جدید
    
    broker_name = AccountInfoString(ACCOUNT_COMPANY);
    symbol_name = _Symbol;

    PrintFormat("Griffin Sender v3.0 started for %s.", broker_name);
    PrintFormat("Sending data to: %s", InpServerUrl);
    PrintFormat("Please ensure the URL is added to the list of allowed WebRequests.");
    
    last_slippage_test_time = TimeCurrent();
    last_latency_test_time = TimeCurrent();
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    MqlTick last_tick;
    if(!SymbolInfoTick(symbol_name, last_tick))
        return;

    // --- بخش ۱: ارسال داده تیک ---
    string tick_message = StringFormat("%s,%s,%d,%.5f,%.5f",
                                       broker_name,
                                       symbol_name,
                                       last_tick.time_msc,
                                       last_tick.bid,
                                       last_tick.ask);
    SendRequest(tick_server_url, tick_message);
    
    datetime current_time = TimeCurrent();
    
    // --- بخش ۲: اجرای تست لغزش شبیه‌سازی شده ---
    if(current_time - last_slippage_test_time >= InpSlippageTestIntervalSeconds)
    {
        last_slippage_test_time = current_time;
        string buy_test_message = StringFormat("%s,%s,%d,BUY,%.5f,0.01",
                                               broker_name, symbol_name, last_tick.time_msc, last_tick.ask);
        string sell_test_message = StringFormat("%s,%s,%d,SELL,%.5f,0.01",
                                                broker_name, symbol_name, last_tick.time_msc, last_tick.bid);
        SendRequest(slippage_server_url, buy_test_message);
        SendRequest(slippage_server_url, sell_test_message);
    }
    
    // --- بخش ۳: جدید - اجرای تست تأخیر ---
    if(current_time - last_latency_test_time >= InpLatencyTestIntervalSeconds)
    {
        last_latency_test_time = current_time;
        
        // زمان ارسال را به میلی‌ثانیه ذخیره می‌کنیم
        long start_time_ms = GetTickCount();
        
        // یک پیام پینگ ساده ارسال می‌کنیم
        string latency_message = StringFormat("%s,%s,%d", broker_name, symbol_name, start_time_ms);
        SendRequest(latency_server_url, latency_message);
        
        // در این مدل ساده، ما پاسخ سرور را پردازش نمی‌کنیم.
        // سرور خودش زمان دریافت را با زمان ارسال مقایسه کرده و تأخیر را محاسبه می‌کند.
    }
}

//+------------------------------------------------------------------+
//| تابع کمکی برای ارسال درخواست‌های وب                               |
//+------------------------------------------------------------------+
void SendRequest(string url, string message)
{
    int message_length = StringToCharArray(message, post_data, 0, -1, CP_UTF8);
    
    uchar result[];
    string result_headers;
    int timeout = 500;
    string headers = "Content-Type: text/plain\r\n";
    
    int res = WebRequest("POST", url, headers, timeout, post_data, result, result_headers);
    
    if(res == -1)
    {
        Print("WebRequest to ", url, " failed. Error code: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("Griffin Sender v3.0 stopped.");
}
//+------------------------------------------------------------------+
