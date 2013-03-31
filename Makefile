install:
	install -d /etc
	install -d /etc/init.d
	install -d /etc/ubic/service
	install -d /usr/sbin
	install -d /var/log/dynpddd
	install -m600 $(CURDIR)/src/dynpddd.conf		$(DESTDIR)/etc/dynpddd.conf
	install -m755 $(CURDIR)/src/dynpddd.pl			$(DESTDIR)/usr/sbin/dynpddd.pl
	install -m755 $(CURDIR)/src/dynpddd.init.d		$(DESTDIR)/etc/init.d/dynpddd
	install -m755 $(CURDIR)/src/dynpddd.ubic.service	$(DESTDIR)/etc/ubic/service/dynpddd

