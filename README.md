# CONV
2019 IC Design Contest Preliminary Practice
# Hardware Accelerator: Convolution (CONV) Engine 
> **Developed by andy**

## 📌 Project Overview
此專案實作了一個基於 Verilog 的硬體卷積運算加速器。本設計旨在實現數位影像處理中的卷積運算（3x3 Kernel），依序完成 Zero-padding, Convolution, ReLU, Max-pooling 並存入記憶體，並達成題目要求。

本專案不僅以 RTL 設計達成功能，更側重於縮小晶片面積。

## 🛠 Technical Highlights
* **Core Logic:** 使用 Verilog 實作卷積運算邏輯，處理資料輸入、權重配對與乘加運算 (Multiply-Accumulate)。
* **Data Flow Management:** 實作 Window Buffer，有效管理資料在週期 (Cycle) 間的滑動與同步。
* **FSM Control:** 獨立設計有限狀態機 (FSM) 控管 Load、Compute、Store 階段，確保資料流的嚴謹性。

## 🏗 Hardware Architecture
* **Input Size:** 64x64
* **Kernel Size:** 3x3
* **Stride:** 1 / **Zero Padding:** 1 
* **Data Width:** 4-bits Interger + 16-bits Float

*(資料流架構圖)*

## 🔍 Verification & Debugging
此設計通過以下測試驗證：
1. **Functional Verification:** RTL code 與 IP 皆透過 Testbench 餵入資料，並與 Golden Model 進行逐一比對，並且通過。
2. **APR Result:** 無 DRC 錯誤，時序皆通過。

## 📈 Simulation Result
*(Testbench Result)*
<img width="1582" height="833" alt="螢幕擷取畫面 2026-02-15 174456" src="https://github.com/user-attachments/assets/76cf5498-333b-499f-845a-9afb85ca98c4" />
*(RTL Synthesis Area Size)*
<img width="1428" height="1029" alt="螢幕擷取畫面 2026-02-15 174622" src="https://github.com/user-attachments/assets/bc6552dd-ddf4-4b98-a93d-359390b46ca3" />
*(IP Area Size)*
<img width="1314" height="882" alt="螢幕擷取畫面 2026-02-15 174207" src="https://github.com/user-attachments/assets/f0ae11c7-6ffd-49d5-9adc-f952885afa5d" />
*(IP Preview)*
<img width="1462" height="1270" alt="螢幕擷取畫面 2026-02-15 173703" src="https://github.com/user-attachments/assets/c404c388-afd6-4328-b367-77530fc3044b" />


## 🚀 Key Learning & Growth
在這個專案中，我從最初的 **RTL 刻劃** 到 **APR 合成繞線** 這個過程讓我深刻理解了：
* **實現方案的架構決定：** 由於 Flip-Flop 單元佔用面積大，對於最小化面積的目標從減少 Register 的使用為優先方向，所以 Buffer 需等於 Kernel 才能最小化面積。而最初的 Zig-Zag 掃描方案旨在不浪費 Buffer 已讀取數值，但由於邏輯過於複雜且深度過深，最終導致難以繞線，改為逐行掃描即大幅改善問題。
* **模組化設計：** 將運算單元與控制單元分離，大幅提升了 Debug 的效率與代碼的可讀性。
