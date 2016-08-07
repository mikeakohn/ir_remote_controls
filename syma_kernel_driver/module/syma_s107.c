/*
 *  derived from "zhenhua.c"
 *  derived from "twidjoy.c"
 *
 *  Copyright (c) 2012 Michael A. Kohn
 *  Copyright (c) 2008 Martin Kebert
 *  Copyright (c) 2001 Arndt Schoenewald
 *  Copyright (c) 2000-2001 Vojtech Pavlik
 *  Copyright (c) 2000 Mark Fletcher
 *
 */

/*
 * Driver for the Syma S107 IR helicopter.  Infrared data is picked up
 * by an IR receiver and read into 4 command bytes by an MSP430 CPU.
 * A sync byte of 0xff and then the 4 bytes is sent over rs232 to
 * a PC.  The packet format is:
 *
 * 0: sync
 * 1: yaw
 * 2: pitch
 * 3: throttle  (bit 7 of the throttle has the state of the A/B switch)
 * 4: correction
 *
 * Schematic at http://www.mikekohn.net/
 */

/*
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/slab.h>
#include <linux/input.h>
#include <linux/serio.h>
#include <linux/init.h>

#define DRIVER_DESC "Syma s017 IR transmitter joystick driver"

MODULE_DESCRIPTION(DRIVER_DESC);
MODULE_LICENSE("GPL");

/*
 * Constants.
 */

#define SYMA_S107_PACKET_LEN 4

struct syma_s107
{
  struct input_dev *dev;
  int idx;
  unsigned char data[SYMA_S107_PACKET_LEN];
  char phys[32];
};

/*
 * syma_s107_interrupt() is called by the low level driver when characters
 * are ready for us. We then buffer them for further processing, or call the
 * packet processing routine.
 */

static irqreturn_t syma_s107_interrupt(struct serio *serio, unsigned char data, unsigned int flags)
{
  struct syma_s107 *syma_s107 = serio_get_drvdata(serio);

  if (data == 0xff)
  {
    /* this byte starts a new packet */
    syma_s107->idx = 0;
  }
    else
  {
    struct input_dev *dev = syma_s107->dev;
    const int idx = syma_s107->idx;

    switch(idx)
    {
      case 0:
        if (data != syma_s107->data[idx])
        {
          data = 0x7f - data;
          syma_s107->data[idx] = data;
          input_report_abs(dev, ABS_X, data);
        }
        break;
      case 1:
        if (data != syma_s107->data[idx])
        {
          syma_s107->data[idx] = data;
          input_report_abs(dev, ABS_Y, data);
        }
        break;
      case 2:
        data = data & 0x7f;
        if (data != syma_s107->data[idx])
        {
          syma_s107->data[idx] = data;
          input_report_abs(dev, ABS_Z, data);
        }
        break;
      default:
        break;
    }

    syma_s107->idx++;
  }

  return IRQ_HANDLED;
}

/*
 * syma_s107_disconnect() is the opposite of syma_s107_connect()
 */

static void syma_s107_disconnect(struct serio *serio)
{
  struct syma_s107 *syma_s107 = serio_get_drvdata(serio);

  printk("Disconnect syma s107\n");

  serio_close(serio);
  serio_set_drvdata(serio, NULL);
  input_unregister_device(syma_s107->dev);
  kfree(syma_s107);
}

/*
 * syma_s107_connect() is the routine that is called when someone adds a
 * new serio device. It looks for the syma_s107, and if found, registers
 * it as an input device.
 */

static int syma_s107_connect(struct serio *serio, struct serio_driver *drv)
{
  struct syma_s107 *syma_s107;
  struct input_dev *input_dev;
  int err = -ENOMEM;

  printk("Connecting syma s107\n");

  syma_s107 = kzalloc(sizeof(struct syma_s107), GFP_KERNEL);
  input_dev = input_allocate_device();
  if (!syma_s107 || !input_dev) goto fail1;

  syma_s107->idx = 4;
  syma_s107->dev = input_dev;
  snprintf(syma_s107->phys, sizeof(syma_s107->phys), "%s/input0", serio->phys);

  input_dev->name = "Syma S107 IR remote joystick";
  input_dev->phys = syma_s107->phys;
  input_dev->id.bustype = BUS_RS232;
  input_dev->id.vendor = SERIO_ZHENHUA;
  input_dev->id.product = 0x0001;
  input_dev->id.version = 0x0100;
  input_dev->dev.parent = &serio->dev;

  input_dev->evbit[0] = BIT(EV_ABS);
  input_set_abs_params(input_dev, ABS_X, 1, 127, 0, 0);
  input_set_abs_params(input_dev, ABS_Y, 1, 127, 0, 0);
  input_set_abs_params(input_dev, ABS_Z, 1, 127, 0, 0);
  //input_set_abs_params(input_dev, ABS_RZ, 50, 200, 0, 0);

  serio_set_drvdata(serio, syma_s107);

  printk("syma s107: serio_open()\n");

  err = serio_open(serio, drv);
  if (err) goto fail2;

  printk("syma s107: input_register()\n");
  err = input_register_device(syma_s107->dev);
  if (err) goto fail3;

  printk("Success: syma s107 connection\n");

  return 0;

  fail3:serio_close(serio);
  fail2:serio_set_drvdata(serio, NULL);
  fail1:input_free_device(input_dev);
  kfree(syma_s107);
  return err;
}

/*
 * The serio driver structure.
 */

static struct serio_device_id syma_s107_serio_ids[] =
{
  {
    .type = SERIO_RS232,
    .proto = SERIO_ZHENHUA,
    .id = SERIO_ANY,
    .extra = SERIO_ANY,
  },
  { 0 }
};

MODULE_DEVICE_TABLE(serio, syma_s107_serio_ids);

static struct serio_driver syma_s107_drv =
{
  .driver =
  {
    .name = "syma_s107",
  },
  .description = DRIVER_DESC,
  .id_table = syma_s107_serio_ids,
  .interrupt = syma_s107_interrupt,
  .connect = syma_s107_connect,
  .disconnect = syma_s107_disconnect,
};

/*
 * The functions for inserting/removing us as a module.
 */

static int __init syma_s107_init(void)
{
  printk("Init syma s107\n");
  return serio_register_driver(&syma_s107_drv);
}

static void __exit syma_s107_exit(void)
{
  printk("Exit syma s107\n");
  serio_unregister_driver(&syma_s107_drv);
}

module_init(syma_s107_init);
module_exit(syma_s107_exit);

