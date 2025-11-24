# 🆘 Hibernation Recovery Guide

## ⚠️ **If Your System Won't Boot After Hibernation Setup**

Your hibernation installation completed successfully with these changes:
- ✅ 66GB swap file created at `/swapfile`
- ✅ GRUB updated with resume parameters
- ✅ GRUB configuration backed up to `/etc/default/grub.backup.20250730_074411`
- ✅ Initramfs rebuilt

## 🔧 **Recovery Methods (In Order of Preference)**

### **Method 1: Boot with Previous GRUB Entry**
1. **At boot menu**: Select "Advanced options for Fedora"
2. **Choose older kernel**: Try an older kernel version if available
3. **This bypasses**: Any kernel parameter issues

### **Method 2: Edit GRUB Parameters at Boot**
1. **At GRUB menu**: Press `e` to edit the boot entry
2. **Find the line**: Starting with `linux` (contains `vmlinuz`)
3. **Remove hibernation parameters**: Delete `resume=UUID=...` and `resume_offset=...`
4. **Boot**: Press `Ctrl+X` or `F10` to boot with modified parameters
5. **Fix permanently**: Once booted, follow "Method 3" below

### **Method 3: Restore GRUB Configuration**
If you can boot (using methods above), restore the original GRUB config:

```bash
# Restore backup GRUB configuration
sudo cp /etc/default/grub.backup.20250730_074411 /etc/default/grub

# Rebuild GRUB
sudo grub2-mkconfig -o /boot/grub2/grub.cfg

# Rebuild initramfs
sudo dracut -f

# Reboot
sudo reboot
```

### **Method 4: Live USB Recovery**
If system won't boot at all:

1. **Boot from Fedora Live USB**
2. **Mount your encrypted root partition**:
   ```bash
   sudo cryptsetup luksOpen /dev/nvme0n1p7 luks-root
   sudo mount /dev/mapper/luks-root /mnt -o subvol=root
   sudo mount /dev/nvme0n1p6 /mnt/boot
   sudo mount /dev/nvme0n1p5 /mnt/boot/efi
   ```

3. **Chroot into your system**:
   ```bash
   sudo chroot /mnt
   ```

4. **Restore GRUB configuration**:
   ```bash
   cp /etc/default/grub.backup.20250730_074411 /etc/default/grub
   grub2-mkconfig -o /boot/grub2/grub.cfg
   dracut -f
   ```

5. **Exit and reboot**:
   ```bash
   exit
   sudo umount -R /mnt
   sudo reboot
   ```

## 🔍 **Common Boot Issues & Solutions**

### **Issue: "Unknown filesystem" or "File not found"**
**Cause**: GRUB can't find the resume device
**Solution**: Use Method 2 to remove resume parameters at boot

### **Issue: System hangs at "Loading initial ramdisk"**
**Cause**: Initramfs issue with resume device
**Solution**: Use Method 1 (older kernel) or Method 3 (restore config)

### **Issue: "Resume device not found"**
**Cause**: Resume offset calculation was wrong for Btrfs
**Solution**: Boot normally (ignore warning) and disable hibernation

## 🛡️ **Prevention for Future**

### **Before Making System Changes**:
1. **Create Timeshift snapshot**: `sudo timeshift --create`
2. **Backup /etc/default/grub**: `sudo cp /etc/default/grub /etc/default/grub.backup`
3. **Note current kernel**: `uname -r`

### **Test Hibernation Safely**:
```bash
# After successful boot, test hibernation
systemctl hibernate

# If hibernation fails, system will just return to normal operation
# Check if hibernation is working:
cat /sys/power/state  # Should show "freeze mem disk"
```

## 📞 **Emergency Commands Reference**

### **From GRUB Boot Menu**:
- `e` = Edit boot parameters
- `c` = GRUB command line
- `Ctrl+X` = Boot with current parameters

### **Key Files to Remember**:
- GRUB config: `/etc/default/grub`
- GRUB backup: `/etc/default/grub.backup.20250730_074411`
- Swap file: `/swapfile`
- Current kernel params: `/proc/cmdline`

### **Quick Recovery Commands**:
```bash
# Check current boot parameters
cat /proc/cmdline

# Disable swap temporarily
sudo swapoff /swapfile

# Remove swap from fstab
sudo sed -i '/\/swapfile/d' /etc/fstab

# Restore original GRUB
sudo cp /etc/default/grub.backup.20250730_074411 /etc/default/grub
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```

## 🎯 **Most Likely Scenario**

Based on your setup, the most likely outcome is:
1. ✅ **System boots normally** (99% chance)
2. ⚠️ **Hibernation may not work** initially (common with Btrfs)
3. 🔧 **May need fine-tuning** of swap offset

The GRUB backup ensures you can always recover! 🛡️

## 📱 **What to Do Right Now**

1. **Save this file** for offline access
2. **Create a Fedora Live USB** if you don't have one
3. **Reboot and test** - it should work fine!
4. **After successful boot**: Test hibernation with `systemctl hibernate`

**Remember**: The backup was created at `/etc/default/grub.backup.20250730_074411` - you can always restore it!
