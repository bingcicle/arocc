//aro-args -std=c23 --target=x86_64-linux -Wno-c23-extensions -ffreestanding
#include <stdint.h>
_Static_assert(sizeof(int128_t) == __SIZEOF_INT128__);
_Static_assert(INT128_WIDTH == 128);
_Static_assert(UINT128_MAX == 340282366920938463463374607431768211455WBU);
_Static_assert(INT128_MAX == 170141183460469231731687303715884105727WB);
_Static_assert(INT128_MIN == -170141183460469231731687303715884105728WB);
_Static_assert(INT128_C(-170141183460469231731687303715884105728) == -170141183460469231731687303715884105728wb);
_Static_assert(UINT128_C(340282366920938463463374607431768211455) == 340282366920938463463374607431768211455uwb);