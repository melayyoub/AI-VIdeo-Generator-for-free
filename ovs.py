#!/usr/bin/env python3
"""OpenVideo Studio CLI entry point.

Alias for the historical `wan2_cli.py` launcher; both stay supported. The
launcher reads `OVS_*` environment variables first, with the legacy
`CUSTOM_WAN_*` names as fallback.
"""

from wan2_cli import main

if __name__ == "__main__":
    main()
