/* Diagnostic kernel only: read the verified Fire OS 6 RAM-console buffer. */
#include <linux/capability.h>
#include <linux/errno.h>
#include <linux/fs.h>
#include <linux/init.h>
#include <linux/mm.h>
#include <linux/module.h>
#include <linux/proc_fs.h>
#include <asm/memory.h>

/* ponytail: one verified buffer, never a general physical-memory interface. */
#define CONSOLE_ADDR 0x44400000UL
#define CONSOLE_SIZE 0x10000UL
#define CONSOLE_SIG  0x43474244U

static bool valid_console(const u32 *h)
{
	return h[0] == CONSOLE_SIG && h[10] == CONSOLE_SIZE &&
		h[12] >= 16 * sizeof(u32) && h[12] < CONSOLE_SIZE &&
		h[15] > 0 && h[15] <= CONSOLE_SIZE - h[12] &&
		h[13] <= h[15] && h[14] <= h[15];
}

static ssize_t console_read(struct file *file, char __user *buf,
			    size_t count, loff_t *pos)
{
	const u32 *header = (const u32 *)__va(CONSOLE_ADDR);
	unsigned long pfn;

	if (!capable(CAP_SYS_RAWIO))
		return -EPERM;
	/* Refuse to read if the matching early reservation was not honored. */
	for (pfn = CONSOLE_ADDR >> PAGE_SHIFT;
	     pfn < (CONSOLE_ADDR + CONSOLE_SIZE) >> PAGE_SHIFT; pfn++) {
		if (!pfn_valid(pfn) || !PageReserved(pfn_to_page(pfn)))
			return -EBUSY;
	}
	if (!valid_console(header))
		return -ENODATA;
	return simple_read_from_buffer(buf, count, pos, header, CONSOLE_SIZE);
}

static const struct file_operations console_fops = {
	.owner = THIS_MODULE,
	.read = console_read,
	.llseek = no_llseek,
};

static int __init console_reader_init(void)
{
	u32 sample[16] = {
		[0] = CONSOLE_SIG, [10] = CONSOLE_SIZE,
		[12] = 64, [15] = CONSOLE_SIZE - 64,
	};

	/* Runnable format/bounds regression check before exposing the reader. */
	if (!valid_console(sample))
		return -EINVAL;
	sample[12] = CONSOLE_SIZE + 4;
	if (valid_console(sample))
		return -EINVAL;
	sample[12] = 64;
	sample[14] = CONSOLE_SIZE;
	if (valid_console(sample))
		return -EINVAL;
	if (!proc_create("biscuit_fireos6_console", 0400, NULL, &console_fops))
		return -ENOMEM;
	pr_info("[DEBUG-biscuit-ramconsole] read-only console reader ready\n");
	return 0;
}
late_initcall(console_reader_init);
