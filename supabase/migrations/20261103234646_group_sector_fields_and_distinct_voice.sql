-- BARQLO historical migration (schema / function definition; original SQL retained)
-- Source: remote supabase_migrations.schema_migrations (read-only extraction 2026-11-05)
-- Recorded version: 20261103234646
-- Recorded name: 20261103234700_group_sector_fields_and_distinct_voice
-- Not standalone: requires the earlier BARQLO database baseline, which is NOT in this repo.
-- Do not run these migrations against the live production database.

WITH next_version AS (
  SELECT sector_code, max(version)+1 AS version
  FROM public.sector_pack_versions
  WHERE sector_code IN ('real_estate','clinic','restaurant')
  GROUP BY sector_code
), updated AS (
  UPDATE public.sector_packs AS sp
  SET version=nv.version,
      style_opening=CASE sp.sector_code
        WHEN 'clinic' THEN 'ابدأ بترحيب مهني قصير ثم إجابة مباشرة عن الكشف أو الطبيب. تجنب عبارات الطمأنة الصحية العامة مثل اطمن قبل معرفة الحالة.'
        WHEN 'restaurant' THEN 'ابدأ باسم الصنف الذي طلبه العميل مباشرة وبأسلوب مطعم لبق، دون مقدمة تقريرية أو ترويج قبل الإجابة.'
        ELSE sp.style_opening END,
      style_highlight=CASE sp.sector_code
        WHEN 'real_estate' THEN 'للوحدة الواحدة: عنوان فيه رمز الوحدة والحالة في السطر نفسه، ثم اجمع المشروع والموقع في سطر، المساحة والغرف والتشطيب في سطر، والسعر في سطر. عند السؤال عن السداد اجمع المقدم والخطة والحجز في سطر أو فقرة قصيرة من بيانات الوحدة فقط. لا تكرر رمز الوحدة أو الحالة. للقائمة: نقطة مختصرة لكل خيار ثم تفاصيل عند الطلب.'
        WHEN 'clinic' THEN 'اعرض اسم الخدمة والطبيب المطلوب بوضوح، واجمع السعر والمدة في سطر واحد، ثم أيام هذا الطبيب المؤكدة ومتطلبات الزيارة في سطور قصيرة. اذكر الخدمات أو الأطباء الآخرين فقط لو سأل عن الخيارات. لا توحِ بتشخيص أو تأكيد حجز.'
        WHEN 'restaurant' THEN 'اجمع اسم الصنف وحجمه في عنوان قصير، والسعر والتوافر في سطر واحد، واسم الفرع مرة واحدة. إن طلب العميل اقتراحا، اذكر صنفا واحدا ملائما من الداتا مع سعره في جملة طبيعية؛ لا تكرر قائمة حقول أو عنوان الفرع لكل صنف.'
      END,
      item_fields=CASE sp.sector_code
        WHEN 'real_estate' THEN '["رمز الوحدة والحالة معا","المشروع والموقع معا","المساحة والغرف والتشطيب معا","السعر","المقدم والخطة والحجز معا عند السؤال"]'::jsonb
        WHEN 'clinic' THEN '["الخدمة والطبيب المطلوب معا","السعر والمدة معا","أيام الطبيب المؤكدة","متطلبات الزيارة عند السؤال"]'::jsonb
        WHEN 'restaurant' THEN '["الصنف والحجم معا","السعر والتوافر معا","الفرع مرة واحدة","اقتراح واحد بجملة قصيرة عند الطلب"]'::jsonb
      END,
      updated_at=now()
  FROM next_version nv
  WHERE sp.sector_code=nv.sector_code
  RETURNING sp.*
)
INSERT INTO public.sector_pack_versions
(sector_code,version,display_name,style_opening,style_highlight,style_close,selling_steps,item_fields,forbidden_actions,escalation_triggers,memory_keys,terminology,created_at,updated_at)
SELECT sector_code,version,display_name,style_opening,style_highlight,style_close,selling_steps,item_fields,forbidden_actions,escalation_triggers,memory_keys,terminology,now(),now() FROM updated;
