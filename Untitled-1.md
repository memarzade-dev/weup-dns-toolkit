-----

## اسکریپت مدیریت سرور لینوکس: کنترل پنل SSH و Firewall

درخواست شما برای یک اسکریپت مدیریت سرور لینوکس حرفه‌ای و جامع که قابلیت‌هایی مانند تغییر پورت SSH، نمایش hostname و IP اصلی، و مدیریت فایروال (شامل نصب در صورت عدم وجود) را به صورت یک کنترل پنل ارائه دهد، کاملا منطقی و کاربردی است.

**نکات مهم قبل از استفاده:**

  * **محیط اجرا:** این اسکریپت برای سیستم‌عامل‌های لینوکس بر پایه Debian/Ubuntu و CentOS/RHEL طراحی شده است.
  * **مجوزها:** برای اجرای این اسکریپت، به دسترسی **root** نیاز دارید.
  * **پشتیبان‌گیری:** همیشه قبل از انجام تغییرات مهم در سرور خود، یک نسخه پشتیبان تهیه کنید.
  * **امنیت:** در حالی که این اسکریپت به مدیریت امنیتی سرور شما کمک می‌کند، استفاده صحیح و دانش کافی از مفاهیم امنیتی لینوکس ضروری است.
  * **فایروال:** این اسکریپت برای مدیریت **UFW** (در Debian/Ubuntu) و **firewalld** (در CentOS/RHEL) طراحی شده است. اگر از فایروال دیگری استفاده می‌کنید، باید اسکریپت را متناسب با آن تغییر دهید.

-----

## اسکریپت Bash: `server_manager.sh`

برای ایجاد این اسکریپت، می‌توانید یک فایل جدید با نام `server_manager.sh` ایجاد کرده و کد زیر را در آن کپی کنید:

```bash
#!/bin/bash

# --- Server Management Script ---
# Author: Your Name (Optional)
# Version: 1.0
# Description: A professional script to manage SSH port, hostname, IP, and firewall settings on a Linux server.

# --- Colors for better UI ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Check for Root Privileges ---
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}خطا: این اسکریپت باید با دسترسی root اجرا شود.${NC}"
        echo -e "${YELLOW}لطفاً با دستور 'sudo su -' یا 'sudo ./server_manager.sh' اجرا کنید.${NC}"
        exit 1
    fi
}

# --- Detect OS Type ---
detect_os() {
    if [ -f /etc/debian_version ]; then
        OS="debian"
        PKG_MANAGER="apt"
    elif [ -f /etc/redhat-release ]; then
        OS="centos"
        PKG_MANAGER="yum"
    else
        echo -e "${RED}سیستم عامل شما پشتیبانی نمی‌شود. این اسکریپت برای Debian/Ubuntu و CentOS/RHEL است.${NC}"
        exit 1
    fi
    echo -e "${BLUE}سیستم عامل شناسایی شده: ${OS}${NC}"
}

# --- Get Current SSH Port ---
get_current_ssh_port() {
    SSH_CONFIG="/etc/ssh/sshd_config"
    CURRENT_SSH_PORT=$(grep -i '^Port' "$SSH_CONFIG" | awk '{print $2}' | head -n 1)
    if [ -z "$CURRENT_SSH_PORT" ]; then
        CURRENT_SSH_PORT="22" # Default SSH port
    fi
    echo "$CURRENT_SSH_PORT"
}

# --- Display Server Info ---
display_server_info() {
    echo -e "\n${YELLOW}--- اطلاعات سرور ---${NC}"
    echo -e "${GREEN}Hostname:${NC} $(hostname)"
    echo -e "${GREEN}Primary IP:${NC} $(hostname -I | awk '{print $1}')"
    echo -e "${GREEN}Operating System:${NC} $(lsb_release -ds 2>/dev/null || cat /etc/*release 2>/dev/null | grep -m 1 NAME | cut -d'=' -f2 | tr -d '"')"
    echo -e "${GREEN}Kernel Version:${NC} $(uname -r)"
    echo -e "${GREEN}Current SSH Port:${NC} $(get_current_ssh_port)"
    echo -e "${YELLOW}---------------------${NC}\n"
}

# --- Change SSH Port ---
change_ssh_port() {
    echo -e "\n${YELLOW}--- تغییر پورت SSH ---${NC}"
    CURRENT_PORT=$(get_current_ssh_port)
    echo -e "${BLUE}پورت فعلی SSH شما: ${CURRENT_PORT}${NC}"
    read -p "لطفاً پورت جدید SSH را وارد کنید (مثال: 2222): " NEW_PORT

    if [[ -z "$NEW_PORT" ]]; then
        echo -e "${RED}پورت جدید نمی‌تواند خالی باشد. عملیات لغو شد.${NC}"
        return 1
    fi

    if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || (( NEW_PORT < 1024 )) || (( NEW_PORT > 65535 )); then
        echo -e "${RED}پورت نامعتبر است. لطفاً یک عدد بین 1024 تا 65535 وارد کنید.${NC}"
        return 1
    fi

    if [[ "$NEW_PORT" -eq "$CURRENT_PORT" ]]; then
        echo -e "${YELLOW}پورت جدید با پورت فعلی یکسان است. تغییری اعمال نشد.${NC}"
        return 0
    fi

    SSH_CONFIG="/etc/ssh/sshd_config"
    TEMP_CONFIG=$(mktemp)

    if grep -q "^Port" "$SSH_CONFIG"; then
        sed "s/^Port .*/Port $NEW_PORT/" "$SSH_CONFIG" > "$TEMP_CONFIG"
    else
        cp "$SSH_CONFIG" "$TEMP_CONFIG"
        echo "Port $NEW_PORT" >> "$TEMP_CONFIG"
    fi

    # Update SELinux if on CentOS
    if [ "$OS" == "centos" ]; then
        echo -e "${BLUE}به‌روزرسانی SELinux برای پورت جدید...${NC}"
        semanage port -a -t ssh_port_t -p tcp "$NEW_PORT" 2>/dev/null || true # Add new port
        semanage port -d -t ssh_port_t -p tcp "$CURRENT_PORT" 2>/dev/null || true # Remove old port if it was custom
        echo -e "${GREEN}SELinux به‌روزرسانی شد.${NC}"
    fi

    mv "$TEMP_CONFIG" "$SSH_CONFIG"

    echo -e "${GREEN}پورت SSH به ${NEW_PORT} تغییر یافت.${NC}"
    restart_ssh_service
    echo -e "${YELLOW}لطفاً به خاطر داشته باشید که پس از تغییر پورت، باید از طریق پورت جدید به سرور متصل شوید.${NC}"
    echo -e "${YELLOW}همچنین، مطمئن شوید که پورت جدید در فایروال باز است.${NC}"
}

# --- Restart SSH Service ---
restart_ssh_service() {
    echo -e "${BLUE}راه‌اندازی مجدد سرویس SSH...${NC}"
    if systemctl is-active --quiet sshd; then
        systemctl restart sshd
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}سرویس SSH با موفقیت راه‌اندازی مجدد شد.${NC}"
        else
            echo -e "${RED}خطا در راه‌اندازی مجدد سرویس SSH. لطفاً به صورت دستی بررسی کنید.${NC}"
        fi
    else
        echo -e "${RED}سرویس SSH در حال اجرا نیست یا یافت نشد.${NC}"
    fi
}

# --- Change Hostname ---
change_hostname() {
    echo -e "\n${YELLOW}--- تغییر Hostname ---${NC}"
    echo -e "${BLUE}Hostname فعلی شما: $(hostname)${NC}"
    read -p "لطفاً Hostname جدید را وارد کنید: " NEW_HOSTNAME

    if [[ -z "$NEW_HOSTNAME" ]]; then
        echo -e "${RED}Hostname نمی‌تواند خالی باشد. عملیات لغو شد.${NC}"
        return 1
    fi

    hostnamectl set-hostname "$NEW_HOSTNAME"
    echo -e "${GREEN}Hostname با موفقیت به ${NEW_HOSTNAME} تغییر یافت.${NC}"
    echo -e "${YELLOW}برای اعمال کامل تغییرات، ممکن است نیاز به راه‌اندازی مجدد سیستم داشته باشید.${NC}"
}

# --- Firewall Management (UFW/Firewalld) ---
manage_firewall() {
    echo -e "\n${YELLOW}--- مدیریت فایروال ---${NC}"

    if [ "$OS" == "debian" ]; then
        manage_ufw
    elif [ "$OS" == "centos" ]; then
        manage_firewalld
    fi
}

# --- UFW Management (Debian/Ubuntu) ---
manage_ufw() {
    echo -e "${BLUE}مدیریت UFW (Uncomplicated Firewall)...${NC}"
    if ! command -v ufw &> /dev/null; then
        echo -e "${YELLOW}UFW نصب نیست. آیا مایلید نصب شود؟ (y/n)${NC}"
        read -n 1 -r INSTALL_UFW_CHOICE
        echo
        if [[ $INSTALL_UFW_CHOICE =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}در حال نصب UFW...${NC}"
            $PKG_MANAGER update -y
            $PKG_MANAGER install ufw -y
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}UFW با موفقیت نصب شد.${NC}"
                ufw enable
                ufw default deny incoming
                ufw default allow outgoing
                echo -e "${GREEN}UFW فعال شد و قوانین پیش‌فرض اعمال شد.${NC}"
            else
                echo -e "${RED}خطا در نصب UFW.${NC}"
                return 1
            fi
        else
            echo -e "${YELLOW}نصب UFW لغو شد.${NC}"
            return 1
        fi
    fi

    echo -e "\n${YELLOW}--- گزینه‌های UFW ---${NC}"
    echo "1. وضعیت UFW"
    echo "2. فعال/غیرفعال کردن UFW"
    echo "3. افزودن/حذف قانون (پورت)"
    echo "4. بازنشانی قوانین UFW"
    echo "b. بازگشت به منوی اصلی"
    read -p "لطفاً گزینه مورد نظر را وارد کنید: " UFW_CHOICE

    case "$UFW_CHOICE" in
        1)
            ufw status verbose
            ;;
        2)
            echo -e "${BLUE}فعال/غیرفعال کردن UFW...${NC}"
            read -p "آیا مایلید UFW را فعال (enable) یا غیرفعال (disable) کنید؟ (e/d): " UFW_TOGGLE
            if [[ $UFW_TOGGLE =~ ^[Ee]$ ]]; then
                ufw enable
                echo -e "${GREEN}UFW فعال شد.${NC}"
            elif [[ $UFW_TOGGLE =~ ^[Dd]$ ]]; then
                ufw disable
                echo -e "${YELLOW}UFW غیرفعال شد. (خطرناک!)${NC}"
            else
                echo -e "${RED}گزینه نامعتبر.${NC}"
            fi
            ;;
        3)
            echo -e "${BLUE}افزودن/حذف قانون UFW...${NC}"
            read -p "آیا مایلید قانونی را اضافه (add) یا حذف (delete) کنید؟ (a/d): " RULE_ACTION
            read -p "پورت مورد نظر را وارد کنید (مثال: 80, 2222): " PORT
            read -p "پروتکل (tcp/udp/any - پیش‌فرض: tcp): " PROTOCOL
            PROTOCOL=${PROTOCOL:-tcp} # Default to tcp

            if [[ $RULE_ACTION =~ ^[Aa]$ ]]; then
                ufw allow "$PORT"/"$PROTOCOL"
                echo -e "${GREEN}قانون برای پورت ${PORT}/${PROTOCOL} اضافه شد.${NC}"
            elif [[ $RULE_ACTION =~ ^[Dd]$ ]]; then
                ufw delete allow "$PORT"/"$PROTOCOL"
                echo -e "${YELLOW}قانون برای پورت ${PORT}/${PROTOCOL} حذف شد.${NC}"
            else
                echo -e "${RED}گزینه نامعتبر.${NC}"
            fi
            ufw reload # Apply changes
            ;;
        4)
            echo -e "${RED}هشدار: بازنشانی UFW تمام قوانین را حذف خواهد کرد.${NC}"
            read -p "آیا مطمئن هستید که می‌خواهید UFW را بازنشانی کنید؟ (y/n): " RESET_UFW_CHOICE
            if [[ $RESET_UFW_CHOICE =~ ^[Yy]$ ]]; then
                ufw reset
                echo -e "${GREEN}UFW بازنشانی شد.${NC}"
                ufw enable
                ufw default deny incoming
                ufw default allow outgoing
                echo -e "${GREEN}UFW مجدداً فعال و با قوانین پیش‌فرض تنظیم شد.${NC}"
            else
                echo -e "${YELLOW}بازنشانی UFW لغو شد.${NC}"
            fi
            ;;
        b)
            echo -e "${YELLOW}بازگشت به منوی اصلی.${NC}"
            ;;
        *)
            echo -e "${RED}گزینه نامعتبر. لطفاً یک عدد معتبر را انتخاب کنید.${NC}"
            ;;
    esac
}

# --- Firewalld Management (CentOS/RHEL) ---
manage_firewalld() {
    echo -e "${BLUE}مدیریت Firewalld...${NC}"
    if ! command -v firewall-cmd &> /dev/null; then
        echo -e "${YELLOW}Firewalld نصب نیست. آیا مایلید نصب شود؟ (y/n)${NC}"
        read -n 1 -r INSTALL_FIREWALLD_CHOICE
        echo
        if [[ $INSTALL_FIREWALLD_CHOICE =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}در حال نصب Firewalld...${NC}"
            $PKG_MANAGER update -y
            $PKG_MANAGER install firewalld -y
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Firewalld با موفقیت نصب شد.${NC}"
                systemctl start firewalld
                systemctl enable firewalld
                echo -e "${GREEN}Firewalld فعال شد.${NC}"
            else
                echo -e "${RED}خطا در نصب Firewalld.${NC}"
                return 1
            fi
        else
            echo -e "${YELLOW}نصب Firewalld لغو شد.${NC}"
            return 1
        fi
    fi

    echo -e "\n${YELLOW}--- گزینه‌های Firewalld ---${NC}"
    echo "1. وضعیت Firewalld"
    echo "2. فعال/غیرفعال کردن Firewalld"
    echo "3. افزودن/حذف پورت"
    echo "4. افزودن/حذف سرویس"
    echo "5. بازنشانی Firewalld"
    echo "b. بازگشت به منوی اصلی"
    read -p "لطفاً گزینه مورد نظر را وارد کنید: " FIREWALLD_CHOICE

    case "$FIREWALLD_CHOICE" in
        1)
            firewall-cmd --state
            firewall-cmd --list-all
            ;;
        2)
            echo -e "${BLUE}فعال/غیرفعال کردن Firewalld...${NC}"
            read -p "آیا مایلید Firewalld را فعال (start) یا غیرفعال (stop) کنید؟ (s/p): " FIREWALLD_TOGGLE
            if [[ $FIREWALLD_TOGGLE =~ ^[Ss]$ ]]; then
                systemctl start firewalld
                systemctl enable firewalld
                echo -e "${GREEN}Firewalld فعال شد.${NC}"
            elif [[ $FIREWALLD_TOGGLE =~ ^[Pp]$ ]]; then
                systemctl stop firewalld
                systemctl disable firewalld
                echo -e "${YELLOW}Firewalld غیرفعال شد. (خطرناک!)${NC}"
            else
                echo -e "${RED}گزینه نامعتبر.${NC}"
            fi
            ;;
        3)
            echo -e "${BLUE}افزودن/حذف پورت Firewalld...${NC}"
            read -p "آیا مایلید پورت را اضافه (add) یا حذف (remove) کنید؟ (a/r): " PORT_ACTION
            read -p "پورت مورد نظر را وارد کنید (مثال: 80/tcp, 2222/tcp): " PORT_SPEC

            if [[ $PORT_ACTION =~ ^[Aa]$ ]]; then
                firewall-cmd --permanent --add-port="$PORT_SPEC"
                echo -e "${GREEN}پورت ${PORT_SPEC} اضافه شد.${NC}"
            elif [[ $PORT_ACTION =~ ^[Rr]$ ]]; then
                firewall-cmd --permanent --remove-port="$PORT_SPEC"
                echo -e "${YELLOW}پورت ${PORT_SPEC} حذف شد.${NC}"
            else
                echo -e "${RED}گزینه نامعتبر.${NC}"
            fi
            firewall-cmd --reload # Apply changes
            ;;
        4)
            echo -e "${BLUE}افزودن/حذف سرویس Firewalld...${NC}"
            read -p "آیا مایلید سرویس را اضافه (add) یا حذف (remove) کنید؟ (a/r): " SERVICE_ACTION
            read -p "نام سرویس را وارد کنید (مثال: http, https, ssh): " SERVICE_NAME

            if [[ $SERVICE_ACTION =~ ^[Aa]$ ]]; then
                firewall-cmd --permanent --add-service="$SERVICE_NAME"
                echo -e "${GREEN}سرویس ${SERVICE_NAME} اضافه شد.${NC}"
            elif [[ $SERVICE_ACTION =~ ^[Rr]$ ]]; then
                firewall-cmd --permanent --remove-service="$SERVICE_NAME"
                echo -e "${YELLOW}سرویس ${SERVICE_NAME} حذف شد.${NC}"
            else
                echo -e "${RED}گزینه نامعتبر.${NC}"
            fi
            firewall-cmd --reload # Apply changes
            ;;
        5)
            echo -e "${RED}هشدار: بازنشانی Firewalld تمام قوانین را حذف خواهد کرد.${NC}"
            read -p "آیا مطمئن هستید که می‌خواهید Firewalld را بازنشانی کنید؟ (y/n): " RESET_FIREWALLD_CHOICE
            if [[ $RESET_FIREWALLD_CHOICE =~ ^[Yy]$ ]]; then
                firewall-cmd --zone=public --remove-interface=eth0 --permanent # Example, adjust interface if needed
                firewall-cmd --zone=public --remove-service=ssh --permanent # Example, remove default SSH
                firewall-cmd --reload
                echo -e "${GREEN}Firewalld بازنشانی شد. (ممکن است نیاز به پیکربندی مجدد داشته باشد)${NC}"
            else
                echo -e "${YELLOW}بازنشانی Firewalld لغو شد.${NC}"
            fi
            ;;
        b)
            echo -e "${YELLOW}بازگشت به منوی اصلی.${NC}"
            ;;
        *)
            echo -e "${RED}گزینه نامعتبر. لطفاً یک عدد معتبر را انتخاب کنید.${NC}"
            ;;
    esac
}

# --- Main Menu ---
main_menu() {
    while true; do
        clear
        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}  کنترل پنل مدیریت سرور لینوکس         ${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo -e "${GREEN}1. نمایش اطلاعات سرور${NC}"
        echo -e "${GREEN}2. تغییر پورت SSH${NC}"
        echo -e "${GREEN}3. تغییر Hostname${NC}"
        echo -e "${GREEN}4. مدیریت فایروال (UFW/Firewalld)${NC}"
        echo -e "${RED}5. خروج${NC}"
        echo -e "${BLUE}----------------------------------------${NC}"

        read -p "لطفاً گزینه مورد نظر را انتخاب کنید: " choice

        case "$choice" in
            1)
                display_server_info
                read -p "برای ادامه Enter را فشار دهید..."
                ;;
            2)
                change_ssh_port
                read -p "برای ادامه Enter را فشار دهید..."
                ;;
            3)
                change_hostname
                read -p "برای ادامه Enter را فشار دهید..."
                ;;
            4)
                manage_firewall
                read -p "برای ادامه Enter را فشار دهید..."
                ;;
            5)
                echo -e "${GREEN}خداحافظ!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}گزینه نامعتبر. لطفاً یک عدد بین 1 تا 5 را انتخاب کنید.${NC}"
                read -p "برای ادامه Enter را فشار دهید..."
                ;;
        esac
    done
}

# --- Main Execution Flow ---
check_root
detect_os
main_menu

```

-----

## نحوه استفاده از اسکریپت:

1.  **ایجاد فایل:**
    یک فایل جدید با نام دلخواه (مثلاً `server_manager.sh`) در سرور خود ایجاد کنید:

    ```bash
    nano server_manager.sh
    ```

2.  **کپی کردن کد:**
    کدهای بالا را در فایل `server_manager.sh` کپی کرده و ذخیره کنید (در nano با `Ctrl+X`، سپس `Y` و `Enter`).

3.  **اعطای مجوز اجرا:**
    به فایل اسکریپت مجوز اجرا بدهید:

    ```bash
    chmod +x server_manager.sh
    ```

4.  **اجرای اسکریپت:**
    اسکریپت را با دسترسی root اجرا کنید:

    ```bash
    sudo ./server_manager.sh
    ```

    یا اگر وارد کاربر root شده‌اید:

    ```bash
    ./server_manager.sh
    ```

-----

## قابلیت‌های اسکریپت و توضیح آن‌ها:

  * **رابط کاربری (UI) با رنگ‌بندی:**
    از رنگ‌ها برای نمایش بهتر اطلاعات و هشدارها استفاده شده است.

  * **بررسی دسترسی Root:**
    اسکریپت در ابتدا بررسی می‌کند که آیا با دسترسی `root` اجرا شده است یا خیر. اگر نه، پیامی نمایش داده و از اجرا خارج می‌شود.

  * **شناسایی خودکار سیستم عامل:**
    اسکریپت به طور خودکار تشخیص می‌دهد که سیستم عامل شما Debian/Ubuntu است یا CentOS/RHEL، تا از مدیر بسته مناسب (`apt` یا `yum`) و ابزار فایروال صحیح (`ufw` یا `firewalld`) استفاده کند.

  * **نمایش اطلاعات سرور (گزینه 1):**

      * **Hostname:** نام فعلی سرور را نمایش می‌دهد.
      * **Primary IP:** آدرس IP اصلی سرور را نمایش می‌دهد.
      * **Operating System:** جزئیات سیستم عامل را نمایش می‌دهد.
      * **Kernel Version:** نسخه کرنل لینوکس را نمایش می‌دهد.
      * **Current SSH Port:** پورت SSH فعلی که سرور شما روی آن گوش می‌دهد را نشان می‌دهد.

  * **تغییر پورت SSH (گزینه 2):**

      * این گزینه به شما امکان می‌دهد تا پورت پیش‌فرض SSH (معمولاً 22) را به یک پورت دلخواه دیگر تغییر دهید.
      * پس از تغییر، سرویس SSH به طور خودکار راه‌اندازی مجدد می‌شود.
      * **نکته مهم:** همیشه پس از تغییر پورت SSH، مطمئن شوید که پورت جدید در فایروال شما باز است تا دسترسی SSH قطع نشود. همچنین، برای CentOS، تنظیمات SELinux نیز به‌روزرسانی می‌شود.

  * **تغییر Hostname (گزینه 3):**

      * به شما امکان می‌دهد نام Hostname سرور خود را تغییر دهید.
      * پس از تغییر، ممکن است برای اعمال کامل نیاز به راه‌اندازی مجدد سیستم داشته باشید.

  * **مدیریت فایروال (گزینه 4):**

      * این بخش به صورت هوشمند UFW (برای Debian/Ubuntu) یا Firewalld (برای CentOS/RHEL) را مدیریت می‌کند.
      * **نصب خودکار فایروال:** اگر فایروال مربوطه نصب نباشد، اسکریپت از شما می‌پرسد که آیا مایل به نصب آن هستید یا خیر.
      * **UFW (برای Debian/Ubuntu):**
          * **وضعیت UFW:** وضعیت فعلی و قوانین UFW را نمایش می‌دهد.
          * **فعال/غیرفعال کردن UFW:** به شما امکان می‌دهد UFW را فعال یا غیرفعال کنید.
          * **افزودن/حذف قانون (پورت):** می‌توانید پورت‌های خاصی را برای پروتکل‌های TCP/UDP در فایروال باز یا بسته کنید.
          * **بازنشانی قوانین UFW:** تمام قوانین فایروال را به حالت پیش‌فرض بازنشانی می‌کند (بسیار مفید برای شروع مجدد).
      * **Firewalld (برای CentOS/RHEL):**
          * **وضعیت Firewalld:** وضعیت فعلی و قوانین Firewalld را نمایش می‌دهد.
          * **فعال/غیرفعال کردن Firewalld:** به شما امکان می‌دهد Firewalld را فعال یا غیرفعال کنید.
          * **افزودن/حذف پورت:** می‌توانید پورت‌های خاصی را برای پروتکل‌های TCP/UDP در فایروال باز یا بسته کنید.
          * **افزودن/حذف سرویس:** می‌توانید سرویس‌های از پیش تعریف شده (مانند HTTP, HTTPS, SSH) را در فایروال فعال یا غیرفعال کنید.
          * **بازنشانی Firewalld:** تمام قوانین فایروال را به حالت پیش‌فرض بازنشانی می‌کند.

  * **خروج (گزینه 5):**

      * از اسکریپت خارج می‌شود.

-----

## توسعه‌های احتمالی و ویژگی‌های بیشتر:

این اسکریپت یک پایه قوی برای مدیریت سرور شماست. برای حرفه‌ای‌تر شدن، می‌توانید ویژگی‌های زیر را اضافه کنید:

  * **مدیریت کاربران:** افزودن، حذف و تغییر رمز عبور کاربران.
  * **مدیریت دیسک:** نمایش فضای دیسک، مدیریت پارتیشن‌ها و RAID (پیچیده‌تر).
  * **مدیریت سرویس‌ها:** راه‌اندازی، توقف، راه‌اندازی مجدد و بررسی وضعیت سرویس‌های مختلف (مانند Apache, Nginx, MySQL).
  * **پشتیبان‌گیری:** امکان ایجاد و بازیابی نسخه‌های پشتیبان از فایل‌ها یا دیتابیس‌ها.
  * **به‌روزرسانی سیستم:** گزینه‌ای برای به‌روزرسانی بسته‌های سیستم عامل.
  * **نصب نرم‌افزارهای رایج:** گزینه‌هایی برای نصب وب‌سرورها (Nginx/Apache)، دیتابیس‌ها (MySQL/MariaDB/PostgreSQL) و PHP.
  * **مانیتورینگ:** نمایش مصرف CPU، RAM و شبکه.
  * **اعتبارسنجی ورودی قوی‌تر:** برای تمام ورودی‌های کاربر، اعتبارسنجی دقیق‌تری انجام دهید تا از خطاهای احتمالی جلوگیری شود.
  * **قابلیت ورود به سیستم (Logging):** ثبت تمام اقدامات انجام شده توسط اسکریپت در یک فایل لاگ برای ردیابی.
  * **ساختار ماژولار:** تقسیم اسکریپت به فایل‌های کوچکتر برای هر ماژول (مثلاً `ssh_manager.sh`, `firewall_manager.sh`) و فراخوانی آن‌ها از اسکریپت اصلی.
  * **پشتیبانی از Fail2Ban:** گزینه‌هایی برای نصب و مدیریت Fail2Ban برای افزایش امنیت SSH.

این اسکریپت یک ابزار قدرتمند است که می‌تواند به شما در مدیریت آسان‌تر سرور لینوکس کمک کند. همیشه با احتیاط و آگاهی از تغییراتی که اعمال می‌کنید، از آن استفاده کنید.
