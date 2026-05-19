# 🥗 NutriScan AI

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev/)
[![OpenAI](https://img.shields.io/badge/OpenAI-412991?style=for-the-badge&logo=openai&logoColor=white)](https://openai.com/)
[![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com/)

**NutriScan AI** is your personal intelligent nutrition assistant. Leveraging cutting-edge AI, it helps users understand their food, track nutrients, and maintain a healthy lifestyle through simple scans and personalized insights.

---

## ✨ Features

- 📸 **Smart Food Scanning**: Instantly identify food items using your camera (TFLite & Mobile Scanner).
- 🤖 **AI-Powered Analysis**: Detailed nutritional breakdown (calories, macros, vitamins) powered by Groq/OpenAI.
- 📊 **Nutrient Tracking**: Keep a history of your meals and monitor your progress over time.
- 🧘 **Personalized Diet Plans**: Get meal suggestions tailored to your BMI and health goals.
- ☁️ **Cloud Sync**: Securely store your data and sync across devices using Supabase.
- 📴 **Offline Support**: Access your history even without an internet connection via Hive database.

---

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev)
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **Backend/Auth**: [Supabase](https://supabase.com)
- **AI Integration**: Groq API & OpenAI
- **Local Database**: [Hive](https://pub.dev/packages/hive)
- **Scanning**: [Mobile Scanner](https://pub.dev/packages/mobile_scanner)

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (latest version)
- Android Studio / VS Code
- A Groq/OpenAI API Key
- Supabase Project Credentials

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/uwaim45264/NutriScan-AI-Mobile-App-In-Flutter.git
   cd nutriscan
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Environment Setup**
   Create a `.env` file in the root directory and add your credentials:
   ```env
   GROQ_API_KEY=your_api_key_here
   SUPABASE_URL=your_supabase_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

---

## 📸 Screenshots

| Splash Screen | Home Screen | Food Analysis |
| :---: | :---: | :---: |
| ![Splash](https://via.placeholder.com/200x400?text=Splash+Screen) | ![Home](https://via.placeholder.com/200x400?text=Home+Screen) | ![Analysis](https://via.placeholder.com/200x400?text=Analysis+View) |

---

## 🤝 Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

---

Developed with ❤️ by [Uwaim](https://github.com/uwaim45264)
