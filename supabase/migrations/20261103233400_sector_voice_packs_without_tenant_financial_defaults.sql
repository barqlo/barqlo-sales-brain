-- BARQLO historical migration (schema / function definition; original SQL retained)
-- Source: remote supabase_migrations.schema_migrations (read-only extraction 2026-11-05)
-- Recorded version: 20261103233400
-- Recorded name: 20261103234500_sector_voice_packs_without_tenant_financial_defaults
-- Not standalone: requires the earlier BARQLO database baseline, which is NOT in this repo.
-- Do not run these migrations against the live production database.

WITH next_version AS (
  SELECT sector_code, coalesce(max(version), 0) + 1 AS version
  FROM public.sector_pack_versions
  WHERE sector_code IN ('real_estate','clinic','restaurant')
  GROUP BY sector_code
), updated AS (
  UPDATE public.sector_packs AS sp
  SET version = nv.version,
      style_opening = CASE sp.sector_code
        WHEN 'real_estate' THEN 'ابدأ بإجابة مباشرة عن الوحدة أو نوع العقار المطلوب. عند طلب قائمة فقط اذكر عدد الخيارات المعروضة، ولا تبدأ بعدد كل الكتالوج.'
        WHEN 'clinic' THEN 'افتتاحية مهنية مطمئنة قصيرة تجيب عن الخدمة أو الطبيب المطلوب، بلا مبالغة أو وعد بتأكيد الحجز.'
        WHEN 'restaurant' THEN 'ابدأ بالصنف أو الفرع الذي سأل عنه العميل مباشرة، بأسلوب ودود وخفيف، بلا ترويج لصنف آخر قبل الإجابة.'
      END,
      style_highlight = CASE sp.sector_code
        WHEN 'real_estate' THEN 'نسّق كل خيار بوضوح: اسم الوحدة والمشروع، الموقع، المساحة والغرف، السعر والحالة. أضف التشطيب والسداد والحجز عند سؤال العميل عنها ومن بيانات الوحدة أو السياسة السارية مع توضيح المصدر. لا تسرد كل مزايا المشروع إلا إذا طلبها العميل.'
        WHEN 'clinic' THEN 'رتّب الرد: الخدمة وسعرها، الطبيب إن كان مرتبطا بالخدمة، الأيام إن كانت مؤكدة لهذا الطبيب، ثم المدة أو المتطلبات عند الحاجة. اذكر أي غياب مؤثر بوضوح.'
        WHEN 'restaurant' THEN 'رتّب الرد: اسم الصنف وحجمه وسعره، الفرع والتوافر. اقترح مرافقا واحدا فقط إذا كان موجودا وملائما فعلا، ولا تجعل الاقتراح يحجب إجابة السؤال.'
      END,
      style_close = CASE sp.sector_code
        WHEN 'real_estate' THEN 'اختم بخطوة معاينة واحدة مناسبة، ووجّه التفاوض والتعاقد إلى المالك.'
        WHEN 'clinic' THEN 'اختم بسؤال واحد يساعد على اختيار موعد بعد التحقق من جدول الطبيب، دون ادعاء أن الحجز تأكد.'
        WHEN 'restaurant' THEN 'اختم بسؤال واحد عن الكمية أو الفرع أو تفضيل العميل، دون ادعاء تجهيز الطلب أو تأكيده.'
      END,
      selling_steps = CASE sp.sector_code
        WHEN 'real_estate' THEN '["افهم مواصفات العميل","اعرض الوحدات المطابقة فقط","أبرز السعر والحالة والتفاصيل المطلوبة من الداتا","اقترح معاينة"]'::jsonb
        WHEN 'clinic' THEN '["أجب باطمئنان مهني","اذكر الخدمة والسعر والطبيب وأيامه المؤكدة عند السؤال","اذكر المتطلبات اللازمة","اسأل عن موعد مناسب دون تأكيد غير موثق"]'::jsonb
        WHEN 'restaurant' THEN '["أجب عن الصنف المطلوب","اذكر السعر والحجم والفرع والتوافر","اقترح مرافقة مناسبة من الداتا فقط عند الملاءمة","اسأل عن الكمية أو الفرع"]'::jsonb
      END,
      item_fields = CASE sp.sector_code
        WHEN 'real_estate' THEN '["الوحدة","المشروع","الموقع","المساحة","الغرف","التشطيب عند الحاجة","السعر","الحالة","السداد والحجز عند السؤال"]'::jsonb
        WHEN 'clinic' THEN '["الخدمة","السعر","الطبيب عند توفره","أيام الطبيب المؤكدة","المدة","المتطلبات"]'::jsonb
        WHEN 'restaurant' THEN '["الصنف","الحجم","السعر","الفرع","التوافر"]'::jsonb
      END,
      forbidden_actions = CASE sp.sector_code
        WHEN 'real_estate' THEN '["اختراع سعر أو تفاصيل عقار أو خطة سداد","افتراض دور الوحدة من رمزها","تعميم شروط وحدة على باقي الوحدات","تقديم شرط مالي غير مؤكد على أنه سياسة المالك","تفاوض البوت أو تأكيد عقد بنفسه"]'::jsonb
        WHEN 'clinic' THEN '["تشخيص حالة","وصف علاج","اختراع سعر أو موعد أو أيام طبيب","نسب أيام عمل العيادة إلى طبيب بعينه","تأكيد حجز قبل ثبوته"]'::jsonb
        WHEN 'restaurant' THEN '["اختراع سعر أو صنف أو توافر","اختراع خصم","اقتراح صنف غير ملائم أو غير موجود","تأكيد طلب قبل ثبوته"]'::jsonb
      END,
      updated_at = now()
  FROM next_version AS nv
  WHERE sp.sector_code = nv.sector_code
  RETURNING sp.*
)
INSERT INTO public.sector_pack_versions
(sector_code,version,display_name,style_opening,style_highlight,style_close,selling_steps,item_fields,forbidden_actions,escalation_triggers,memory_keys,terminology,created_at,updated_at)
SELECT sector_code,version,display_name,style_opening,style_highlight,style_close,selling_steps,item_fields,forbidden_actions,escalation_triggers,memory_keys,terminology,now(),now()
FROM updated;
