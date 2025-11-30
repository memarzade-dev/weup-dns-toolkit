#!/bin/bash

# DNS Bypass Script - رفع تحریم با تنظیم بهترین DNS ها
# نسخه: 1.0
# سازنده: Memarzade Development
# مجوز: MIT

# --- رنگ‌ها ---
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# --- بررسی دسترسی Root ---
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ خطا: این اسکریپت باید با دسترسی root اجرا شود${NC}"
        echo -e "${YELLOW}💡 با دستور sudo اجرا کنید: sudo $0${NC}"
        exit 1
    fi
}

# --- نمایش هدر ---
show_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                                                ║${NC}"
    echo -e "${BLUE}║            ${WHITE}${BOLD}DNS BYPASS - رفع تحریم با DNS${NC}${BLUE}                ║${NC}"
    echo -e "${BLUE}║                      ${CYAN}نسخه 1.0${NC}${BLUE}                          ║${NC}"
    echo -e "${BLUE}║                ${CYAN}Memarzade Development${NC}${BLUE}                     ║${NC}"
    echo -e "${BLUE}║                                                                ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
}

# --- پشتیبان‌گیری از تنظیمات فعلی ---
backup_dns() {
    local backup_file="/etc/resolv.conf.backup.$(date +%Y%m%d_%H%M%S)"
    if cp /etc/resolv.conf "$backup_file" 2>/dev/null; then
        echo -e "${GREEN}✅ پشتیبان‌گیری انجام شد: $backup_file${NC}"
    else
        echo -e "${YELLOW}⚠️  نتوانستم پشتیبان‌گیری کنم${NC}"
    fi
}

# --- تست سرعت DNS ---
test_dns_speed() {
    local dns_server="$1"
    local test_domain="google.com"
    
    echo -n "🧪 تست $dns_server ... "
    
    # تست زمان پاسخ
    local start_time=$(date +%s%3N)
    local result=$(timeout 3 nslookup "$test_domain" "$dns_server" 2>/dev/null)
    local end_time=$(date +%s%3N)
    
    if [ $? -eq 0 ] && [ -n "$result" ]; then
        local response_time=$((end_time - start_time))
        echo -e "${GREEN}✅ ${response_time}ms${NC}"
        return 0
    else
        echo -e "${RED}❌ خطا${NC}"
        return 1
    fi
}

# --- تنظیم DNS ---
set_dns() {
    local primary_dns="$1"
    local secondary_dns="$2"
    local description="$3"
    
    echo -e "${BLUE}🔄 تنظیم DNS: $description${NC}"
    
    # پشتیبان‌گیری
    backup_dns
    
    # تنظیم DNS جدید
    cat > /etc/resolv.conf << EOF
# DNS تنظیم شده توسط DNS Bypass Script
# $description
nameserver $primary_dns
nameserver $secondary_dns
EOF
    
    # تست DNS جدید
    echo -e "${CYAN}🧪 تست DNS جدید...${NC}"
    if nslookup google.com >/dev/null 2>&1; then
        echo -e "${GREEN}✅ DNS با موفقیت تنظیم شد${NC}"
        echo -e "${CYAN}📍 DNS اصلی: $primary_dns${NC}"
        echo -e "${CYAN}📍 DNS ثانویه: $secondary_dns${NC}"
    else
        echo -e "${RED}❌ خطا در تنظیم DNS${NC}"
        return 1
    fi
}

# --- تنظیم DNS over HTTPS ---
setup_doh() {
    local doh_server="$1"
    local description="$2"
    
    echo -e "${BLUE}🔒 تنظیم DNS over HTTPS: $description${NC}"
    
    # بررسی systemd-resolved
    if ! systemctl is-active --quiet systemd-resolved; then
        echo -e "${YELLOW}⚠️  systemd-resolved غیرفعال است. فعال‌سازی...${NC}"
        systemctl enable systemd-resolved
        systemctl start systemd-resolved
    fi
    
    # پشتیبان‌گیری تنظیمات
    if [ -f /etc/systemd/resolved.conf ]; then
        cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.backup.$(date +%Y%m%d_%H%M%S)
    fi
    
    # تنظیم DoH
    cat > /etc/systemd/resolved.conf << EOF
[Resolve]
DNS=$doh_server
DNSOverTLS=yes
DNSSEC=yes
FallbackDNS=1.1.1.1 8.8.8.8
EOF
    
    # راه‌اندازی مجدد
    systemctl restart systemd-resolved
    
    # تست
    if systemctl is-active --quiet systemd-resolved; then
        echo -e "${GREEN}✅ DNS over HTTPS تنظیم شد${NC}"
        echo -e "${CYAN}📍 سرور DoH: $doh_server${NC}"
    else
        echo -e "${RED}❌ خطا در تنظیم DNS over HTTPS${NC}"
        return 1
    fi
}

# --- تست سرعت همه DNS ها ---
test_all_dns() {
    echo -e "${CYAN}🚀 تست سرعت همه DNS ها...${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    
    # DNS های بین‌المللی
    echo -e "${YELLOW}📡 DNS های بین‌المللی:${NC}"
    test_dns_speed "1.1.1.1"          # Cloudflare
    test_dns_speed "8.8.8.8"          # Google
    test_dns_speed "9.9.9.9"          # Quad9
    test_dns_speed "208.67.222.222"   # OpenDNS
    
    echo ""
    # DNS های ایرانی
    echo -e "${YELLOW}🇮🇷 DNS های ایرانی:${NC}"
    test_dns_speed "178.22.122.100"   # Shecan
    test_dns_speed "185.55.226.26"    # Begzar
    test_dns_speed "78.157.42.101"    # Electro
    
    echo ""
    # DNS های خاص برای رفع تحریم
    echo -e "${YELLOW}🔓 DNS های ضد تحریم:${NC}"
    test_dns_speed "185.228.168.168"  # AdGuard
    test_dns_speed "76.76.19.19"      # Alternate
    test_dns_speed "94.140.14.14"     # AdGuard Family
}

# --- نمایش DNS فعلی ---
show_current_dns() {
    echo -e "${CYAN}📋 DNS فعلی سیستم:${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    
    if [ -f /etc/resolv.conf ]; then
        echo -e "${GREEN}📄 /etc/resolv.conf:${NC}"
        cat /etc/resolv.conf | grep nameserver
        echo ""
    fi
    
    # نمایش DNS systemd-resolved
    if systemctl is-active --quiet systemd-resolved; then
        echo -e "${GREEN}🔧 systemd-resolved:${NC}"
        systemd-resolve --status | grep -E "DNS Servers|DNS Domain" | head -5
        echo ""
    fi
    
    # تست DNS فعلی
    echo -e "${CYAN}🧪 تست DNS فعلی:${NC}"
    if nslookup google.com >/dev/null 2>&1; then
        echo -e "${GREEN}✅ DNS فعلی کار می‌کند${NC}"
        local dns_ip=$(nslookup google.com | grep -A1 "Name:" | tail -1 | awk '{print $2}')
        echo -e "${CYAN}📍 IP گوگل: $dns_ip${NC}"
    else
        echo -e "${RED}❌ DNS فعلی کار نمی‌کند${NC}"
    fi
}

# --- بازیابی DNS ---
restore_dns() {
    echo -e "${CYAN}🔄 بازیابی DNS...${NC}"
    
    # پیدا کردن آخرین پشتیبان
    local backup_file=$(ls -t /etc/resolv.conf.backup.* 2>/dev/null | head -1)
    
    if [ -n "$backup_file" ] && [ -f "$backup_file" ]; then
        cp "$backup_file" /etc/resolv.conf
        echo -e "${GREEN}✅ DNS از پشتیبان بازیابی شد${NC}"
        echo -e "${CYAN}📍 فایل پشتیبان: $backup_file${NC}"
        
        # تست DNS بازیابی شده
        if nslookup google.com >/dev/null 2>&1; then
            echo -e "${GREEN}✅ DNS بازیابی شده کار می‌کند${NC}"
        else
            echo -e "${RED}❌ DNS بازیابی شده کار نمی‌کند${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  هیچ پشتیبانی پیدا نشد${NC}"
        echo -e "${CYAN}تنظیم DNS پیش‌فرض...${NC}"
        
        # تنظیم DNS پیش‌فرض
        cat > /etc/resolv.conf << EOF
# DNS پیش‌فرض
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF
        echo -e "${GREEN}✅ DNS پیش‌فرض تنظیم شد${NC}"
    fi
}

# --- پاکسازی DNS Cache ---
flush_dns_cache() {
    echo -e "${CYAN}🧹 پاکسازی DNS Cache...${NC}"
    
    # systemd-resolved
    if systemctl is-active --quiet systemd-resolved; then
        systemd-resolve --flush-caches 2>/dev/null || resolvectl flush-caches 2>/dev/null
        echo -e "${GREEN}✅ systemd-resolved cache پاک شد${NC}"
    fi
    
    # nscd
    if command -v nscd &>/dev/null; then
        nscd -i hosts 2>/dev/null
        echo -e "${GREEN}✅ nscd cache پاک شد${NC}"
    fi
    
    # dnsmasq
    if systemctl is-active --quiet dnsmasq; then
        systemctl restart dnsmasq
        echo -e "${GREEN}✅ dnsmasq restart شد${NC}"
    fi
    
    echo -e "${GREEN}✅ DNS Cache پاک شد${NC}"
}

# --- منوی اصلی ---
main_menu() {
    while true; do
        show_header
        
        echo -e "\n${CYAN}📋 DNS فعلی:${NC}"
        grep nameserver /etc/resolv.conf 2>/dev/null | head -2 | sed 's/nameserver /📍 /'
        
        echo -e "\n${CYAN}🛠️  گزینه‌ها:${NC}"
        echo -e "${GREEN}1.${NC}  🚀 تست سرعت همه DNS ها"
        echo -e "${GREEN}2.${NC}  ☁️  Cloudflare DNS (سریع و امن)"
        echo -e "${GREEN}3.${NC}  🔍 Google DNS (پایدار)"
        echo -e "${GREEN}4.${NC}  🛡️  Quad9 DNS (امن و سریع)"
        echo -e "${GREEN}5.${NC}  🇮🇷 Shecan DNS (ایرانی)"
        echo -e "${GREEN}6.${NC}  🇮🇷 Begzar DNS (ایرانی)"
        echo -e "${GREEN}7.${NC}  🔓 AdGuard DNS (ضد تبلیغات)"
        echo -e "${GREEN}8.${NC}  🔒 تنظیم DNS over HTTPS"
        echo -e "${GREEN}9.${NC}  📊 نمایش DNS فعلی"
        echo -e "${GREEN}10.${NC} 🧹 پاکسازی DNS Cache"
        echo -e "${GREEN}11.${NC} 🔄 بازیابی DNS قبلی"
        echo -e "${GREEN}12.${NC} ⚙️  تنظیم DNS دستی"
        echo -e "${RED}0.${NC}  🚪 خروج"
        
        echo ""
        read -p "انتخاب کنید (0-12): " choice
        
        case "$choice" in
            1)
                test_all_dns
                ;;
            2)
                set_dns "1.1.1.1" "1.0.0.1" "Cloudflare DNS - سریع و امن"
                ;;
            3)
                set_dns "8.8.8.8" "8.8.4.4" "Google DNS - پایدار"
                ;;
            4)
                set_dns "9.9.9.9" "149.112.112.112" "Quad9 DNS - امن و سریع"
                ;;
            5)
                set_dns "178.22.122.100" "185.51.200.2" "Shecan DNS - ایرانی"
                ;;
            6)
                set_dns "185.55.226.26" "185.55.225.25" "Begzar DNS - ایرانی"
                ;;
            7)
                set_dns "185.228.168.168" "185.228.169.168" "AdGuard DNS - ضد تبلیغات"
                ;;
            8)
                echo -e "\n${CYAN}🔒 انتخاب DoH Provider:${NC}"
                echo "1. Cloudflare DoH"
                echo "2. Google DoH"
                echo "3. Quad9 DoH"
                read -p "انتخاب کنید (1-3): " doh_choice
                
                case "$doh_choice" in
                    1) setup_doh "1.1.1.1" "Cloudflare DoH" ;;
                    2) setup_doh "8.8.8.8" "Google DoH" ;;
                    3) setup_doh "9.9.9.9" "Quad9 DoH" ;;
                    *) echo -e "${RED}❌ گزینه نامعتبر${NC}" ;;
                esac
                ;;
            9)
                show_current_dns
                ;;
            10)
                flush_dns_cache
                ;;
            11)
                restore_dns
                ;;
            12)
                echo -e "\n${CYAN}⚙️  تنظیم DNS دستی:${NC}"
                read -p "DNS اصلی را وارد کنید: " primary_dns
                read -p "DNS ثانویه را وارد کنید: " secondary_dns
                
                if [[ -n "$primary_dns" && -n "$secondary_dns" ]]; then
                    set_dns "$primary_dns" "$secondary_dns" "DNS دستی"
                else
                    echo -e "${RED}❌ DNS وارد نشده${NC}"
                fi
                ;;
            0)
                echo -e "\n${GREEN}🎉 از اسکریپت DNS Bypass استفاده کردید!${NC}"
                echo -e "${CYAN}💡 برای اتصال بهتر، از VPN هم استفاده کنید${NC}"
                echo -e "${YELLOW}📧 پشتیبانی: support@memarzade.dev${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ گزینه نامعتبر. لطفاً 0-12 انتخاب کنید.${NC}"
                ;;
        esac
        
        if [ "$choice" != "0" ]; then
            echo -e "\n${YELLOW}برای ادامه Enter بزنید...${NC}"
            read
        fi
    done
}

# --- اسکریپت سریع ---
quick_setup() {
    echo -e "${CYAN}🚀 تنظیم سریع DNS برای رفع تحریم...${NC}"
    
    # تست و تنظیم بهترین DNS
    echo -e "${BLUE}🧪 تست DNS های مختلف...${NC}"
    
    # تست Cloudflare
    if test_dns_speed "1.1.1.1" >/dev/null 2>&1; then
        set_dns "1.1.1.1" "1.0.0.1" "Cloudflare DNS - سریع و امن"
        return 0
    fi
    
    # تست Google
    if test_dns_speed "8.8.8.8" >/dev/null 2>&1; then
        set_dns "8.8.8.8" "8.8.4.4" "Google DNS - پایدار"
        return 0
    fi
    
    # تست Shecan
    if test_dns_speed "178.22.122.100" >/dev/null 2>&1; then
        set_dns "178.22.122.100" "185.51.200.2" "Shecan DNS - ایرانی"
        return 0
    fi
    
    echo -e "${RED}❌ هیچ DNS مناسبی پیدا نشد${NC}"
    return 1
}

# --- اجرای اصلی ---
main() {
    # بررسی آرگومان‌ها
    case "${1:-}" in
        --quick|-q)
            check_root
            quick_setup
            ;;
        --test|-t)
            test_all_dns
            ;;
        --help|-h)
            echo -e "${CYAN}DNS Bypass Script - رفع تحریم با DNS${NC}"
            echo -e "${GREEN}استفاده: $0 [گزینه]${NC}"
            echo ""
            echo -e "${YELLOW}گزینه‌ها:${NC}"
            echo "  --quick, -q    تنظیم سریع بهترین DNS"
            echo "  --test, -t     تست سرعت همه DNS ها"
            echo "  --help, -h     نمایش این راهنما"
            echo ""
            echo -e "${CYAN}مثال‌ها:${NC}"
            echo "  $0              # منوی تعاملی"
            echo "  $0 --quick      # تنظیم سریع"
            echo "  $0 --test       # تست سرعت"
            ;;
        "")
            check_root
            main_menu
            ;;
        *)
            echo -e "${RED}❌ گزینه نامعتبر: $1${NC}"
            echo -e "${YELLOW}برای راهنما: $0 --help${NC}"
            exit 1
            ;;
    esac
}

# اجرای اسکریپت
main "$@"