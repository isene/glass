/* xpix: read back what a window shows.
 *   xpix              prints "WIDTH HEIGHT ID ROOT" for the first big window
 *   xpix X Y [X Y..]  prints the colour at each point, one rrggbb per line
 *   xpix -s X Y ..    what the screen shows there: a see-through window
 *                     gives the mix with what is behind it
 */
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv)
{
    Display *d = XOpenDisplay(NULL);
    if (!d) return 1;
    Window r, p, *kids, win = 0;
    unsigned n, i;
    XWindowAttributes a;
    XQueryTree(d, DefaultRootWindow(d), &r, &p, &kids, &n);
    for (i = 0; i < n; i++)
        if (XGetWindowAttributes(d, kids[i], &a) && a.map_state == IsViewable && a.width > 200)
            win = kids[i];
    if (!win) return 2;
    XGetWindowAttributes(d, win, &a);
    if (argc < 3) { printf("%d %d 0x%lx 0x%lx\n", a.width, a.height, win, DefaultRootWindow(d)); return 0; }
    int screen = !strcmp(argv[1], "-s");
    for (i = 1 + screen; i + 1 < (unsigned)argc; i += 2) {
        int x = atoi(argv[i]), y = atoi(argv[i + 1]);
        XImage *im = screen ? XGetImage(d, DefaultRootWindow(d), a.x + x, a.y + y, 1, 1, AllPlanes, ZPixmap)
                            : XGetImage(d, win, x, y, 1, 1, AllPlanes, ZPixmap);
        if (!im) return 3;
        printf("%06lx\n", XGetPixel(im, 0, 0) & 0xffffff);
        XDestroyImage(im);
    }
    return 0;
}
