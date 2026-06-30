# ☁️ CloudVault - Premium Azure Blob Manager

CloudVault is a state-of-the-art Flutter mobile application designed for secure, intelligent, and visually stunning file management using Azure Blob Storage. It bridges the gap between raw cloud storage and a user-friendly personal vault.

---

## ✨ Core Functionalities

### 🔐 The Two-Vault Ecosystem
CloudVault implements a strict separation between public and private data through a virtualized two-vault system:
*   **Public Cloud (Default)**: A high-performance environment for non-sensitive assets. Files are stored at the container root.
*   **Secret Vault (Protected)**: An encrypted-access environment. Files are automatically isolated using a `private/` prefix logic in Azure.
*   **Biometric Unlock**: Pro-tier security supporting Fingerprint and FaceID authentication for instant vault access.

### 📈 Intelligent Data Analysis
*   **Visual Dashboard**: A dedicated screen providing storage insights using **fl_chart**. It visualizes the distribution of file types (Video, Image, Music, etc.).
*   **Context-Aware Stats**: The dashboard dynamically updates its charts based on whether you are currently viewing the Public or Secret vault.
*   **Advanced Sorting**: Organize your data by **Name, Size, or Date** with ascending/descending toggles.

### 📂 Smart Categorization
The app automatically classifies every file upon retrieval using a dual-check system (MIME Type + File Extension):
*   **🎬 Videos**: `.mp4`, `.mov`, `.mkv`, etc.
*   **📸 Images**: `.jpg`, `.png`, `.webp`, `.svg`, etc.
*   **🎵 Music**: `.mp3`, `.wav`, `.aac`, etc.
*   **📄 Documents**: `.pdf`, `.docx`, `.xlsx`, `.txt`, etc.
*   **📦 Others**: Any other unrecognized formats.

### 🛠️ Full CRUD & Multi-Management
*   **Create (Upload)**: Supports multi-format file picking. Automatically detects and toggles "Private" status based on your current vault mode.
*   **Read (Preview)**: Advanced file info modal with metadata display (Last Modified, Content Type, Size) and direct URL opening.
*   **Update (Rename)**: High-level renaming logic that handles Azure copy-and-delete operations seamlessly.
*   **Delete & Bulk Actions**: Supports single deletion and **Multi-Selection Mode** for bulk removal of assets.
*   **Vault Transfer**: Effortlessly move files between the Public Cloud and Secret Vault with the "Move to Vault" pro feature.

---

## 🎨 Premium UI/UX Features

*   **Glassmorphism Surfaces**: Clean, semi-transparent UI elements with backdrop blurs for a high-end feel.
*   **Animated Dynamics**: Fluid, glowing background orbs that react to vault mode changes.
*   **Staggered Entry**: Sophisticated entry animations for grids and lists to ensure a "liquid" user experience.
*   **Responsive Shell**: Adaptive layout that switches between a mobile-friendly bottom-nav/drawer and a desktop-grade sidebar.

---

## 🛡️ Security Architecture

### 1. Identity & Config Management
Unlike standard apps, CloudVault does not rely solely on `.env` files for user-specific data. It uses a local **SQLite** database to manage:
*   **Vault Master Password**: Hashed and stored locally to protect your secret data.
*   **Azure Account Name**: Configurable at runtime, allowing for flexible account switching.

### 2. Azure SAS Authentication
Communicates via **Shared Access Signatures (SAS)**, ensuring that your storage account key is never stored on the device or sent over the network.

---

## 🛠️ Technical Stack

| Category | Technology |
| :--- | :--- |
| **Frontend** | Flutter (Dart) |
| **Backend** | Azure Blob Storage |
| **Local DB** | SQLite (`sqflite`) |
| **State** | `provider` |
| **UI** | `flutter_animate`, `fl_chart`, `google_fonts` |
| **Utils** | `http`, `xml`, `crypto`, `mime`, `intl`, `url_launcher` |

---

## 🚀 Getting Started

### 1. Environment Setup
Create a `.env` file using `.env.example` as a template:
```env
AZURE_STORAGE_CONTAINER_NAME=your_container
AZURE_SAS_KEY=your_sas_token
```

### 2. Identity Initialization
On the first run, navigate to the **Vault** tab. You will be prompted to:
1.  Enter your **Azure Storage Account Name**.
2.  Set your **Master Vault Password**.

These credentials will be securely saved in the local SQLite database.

### 3. Build & Run
```bash
flutter pub get
flutter run
```

---

## 📂 Project Modular Structure

*   `lib/models/`: Robust data structures for blobs and statistics.
*   `lib/providers/`: The app's "brain" managing vault states, filtering, and CRUD logic.
*   `lib/services/`: Direct REST interaction with Azure and local SQLite management.
*   `lib/screens/`: High-performance UI screens optimized for both mobile and web.
*   `lib/widgets/`: Reusable, atomic UI components.
*   `lib/utils/`: Global theme tokens and design system constants.

---

## 🔒 Security Best Practice
Always ensure your Azure SAS token has a limited lifespan and follows the **Principle of Least Privilege** (only grant `rlwd` permissions for the specific container).
